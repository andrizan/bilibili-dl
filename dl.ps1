param(
  [Parameter(Mandatory = $False)]
  [string[]] $eps_id = @()
)

get-content .env | ForEach-Object {
  $name, $value = $_.split('=')
  set-content env:\$name $value
}

Function Write-Log {
  [CmdletBinding()]
  Param(
    [Parameter(Mandatory = $False)]
    [ValidateSet("INFO", "WARN", "ERROR", "FATAL", "DEBUG")]
    [String]
    $Level = "INFO",

    [Parameter(Mandatory = $True)]
    [string]
    $Message
  )

  $logfile = "./tmp/log.log"
  $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss:ffff")
  $Line = "$Stamp $Level $Message"
  If ($logfile) {
    Add-Content $logfile -Value $Line
    if ($Level -eq "INFO") {
      Write-Host $Line -foreground Blue
    }
    elseif ($Level -eq "WARN") {
      Write-Host $Line -foreground Yellow
    }
    elseif ($Level -eq "ERROR") {
      Write-Host $Line -foreground Red
    }
    elseif ($Level -eq "FATAL") {
      Write-Host $Line -foreground Red
    }
    elseif ($Level -eq "DEBUG") {
      Write-Host $Line -foreground Yellow
    }
  }
  Else {
    Write-Output $Line
  }
}

if (!$args[0]) {
  Write-Log "FATAL" "Url not found"
  Break
}

if (!$args[1]) {
  Write-Log "FATAL" "Title null"
  Break
}

$video = "./tmp/$($args[1]).mkv"
$audio = "./tmp/$($args[1]).opus"
$subs = "./tmp/$($args[1]).id.srt"

$result = "../$($args[1]).mkv"
if (Test-Path $result) {
  Write-Log "ERROR" "File '$result' exists"
  Break
}

if (Test-Path $video) {
  Write-Log "INFO" "File '$video' exists"
}
else {
  Write-Log "INFO" "Download video starts"

  Do { yt-dlp.exe -u $env:BILIBILI_USERNAME -p $env:BILIBILI_PASSWORD -f "bv[height<=$($env:BILIBILI_RESOLUTION)]" --remux-video mkv --add-metadata -o "./tmp/$($args[1]).%(ext)s" $args[0] } until ($?)

  Write-Log "INFO" "Download file '$video' finish"
}

if (Test-Path $audio) {
  Write-Log "INFO" "File '$audio' exists"
}
else {
  Write-Log "INFO" "Download audio starts"

  Do { yt-dlp.exe -u $env:BILIBILI_USERNAME -p $env:BILIBILI_PASSWORD -f "ba/b[height<=$($env:BILIBILI_RESOLUTION)]" --add-metadata --postprocessor-args "ffmpeg:-c:a libopus -b:a 96k" -o $audio $args[0] } until ($?)

  Write-Log "INFO" "Download file '$audio' finish"
}

if (Test-Path $subs) {
  Write-Log "INFO" "File '$subs' exists"
}
else {
  Write-Log "INFO" "Download subtitle starts"

  yt-dlp.exe -u $env:BILIBILI_USERNAME -p $env:BILIBILI_PASSWORD --write-subs --sub-langs $env:BILIBILI_SUBTITLE_LANG -o "./tmp/$($args[1])" --add-metadata --skip-download $args[0]
  Write-Log "INFO" "Download file '$subs' finish"
}

if ((Test-Path $video) -and (Test-Path $audio) -and (Test-Path $subs)) {
  ffmpeg -i $video -i $audio -i $subs -c:v copy -c:a copy -c:s srt -disposition:s:0 default "../$($args[1]).mkv"

  Remove-Item $video
  Remove-Item $audio
  Remove-Item $subs
  Write-Log "INFO" "File '$video', '$audio', '$subs' merged"
  Write-Log "INFO" "File '$video' deleted"
  Write-Log "INFO" "File '$audio' deleted"
  Write-Log "INFO" "File '$subs' deleted"
  Write-Log "INFO" "==============FINISH=============="
}else{
  Write-Log "ERROR" "Download file is not complete, run again."
  Write-Log "ERROR" "==============ERROR=============="
}
