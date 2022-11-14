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

	$logfile = "./logging.log"
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

if (!$eps_id) {
	Write-Log "FATAL" "Param eps_id empety"
	Break
}

# if (!$args[1]) {
# 	Write-Log "FATAL" "Title null"
# 	Break
# }

Foreach ($eps_code in $eps_id) {
	$url = "https://www.bilibili.tv/id/play/1022690/" + $eps_code

	$eps = $(yt-dlp.exe --skip-download --get-title --no-warnings -u $env:BILIBILI_USERNAME -p $env:BILIBILI_PASSWORD $url)
	$fix_eps = $eps.split(' ')
	$fix_eps = $fix_eps[0] -replace "[^0-9]" , ''

	$name = "Detective Conan - $($fix_eps)"

	$video = "./tmp/$($name).mkv"
	$audio = "./tmp/$($name).opus"
	$subs = "./tmp/$($name).id.srt"

	$result = "../$($name).mkv"
	if (Test-Path $result) {
		Write-Log "ERROR" "File '$result' exists"
		continue
	}

	if (Test-Path $video) {
		Write-Log "INFO" "File '$video' exists"
	}
	else {
		Write-Log "INFO" "Download video starts"

		Do { yt-dlp.exe -u $env:BILIBILI_USERNAME -p $env:BILIBILI_PASSWORD -f "bv[height<=$($env:BILIBILI_RESOLUTION)]" --remux-video mkv --add-metadata -o "./tmp/$($name).%(ext)s" --downloader aria2c --external-downloader-args "aria2c:-c -j 16 -s 16 -x 16 -k 2M" $url } until ($?)

		Write-Log "INFO" "Download file '$video' finish"
	}

	if (Test-Path $audio) {
		Write-Log "INFO" "File '$audio' exists"
	}
	else {
		Write-Log "INFO" "Download audio starts"

		Do { yt-dlp.exe -u $env:BILIBILI_USERNAME -p $env:BILIBILI_PASSWORD -f "ba/b[height<=$($env:BILIBILI_RESOLUTION)]" --add-metadata --postprocessor-args "ffmpeg:-c:a libopus -b:a 64k" -o $audio --downloader aria2c --external-downloader-args "aria2c:-c -j 16 -s 16 -x 16 -k 2M" $url } until ($?)

		# Do { yt-dlp.exe -u $env:BILIBILI_USERNAME -p $env:BILIBILI_PASSWORD -f "ba/b[height<=$($env:BILIBILI_RESOLUTION)]" --add-metadata --postprocessor-args "ffmpeg:-c:a libopus -b:a 64k -af 'pan=stereo|FL=0.5FC+0.707FL+0.707BL+0.5LFE|FR=0.5FC+0.707FR+0.707BR+0.5LFE'" -o $audio --downloader aria2c --external-downloader-args "aria2c:-c -j 16 -s 16 -x 16 -k 2M" $url } until ($?)

		Write-Log "INFO" "Download file '$audio' finish"
	}

	if (Test-Path $subs) {
		Write-Log "INFO" "File '$subs' exists"
	}
	else {
		Write-Log "INFO" "Download subtitle starts"

		yt-dlp.exe -u $env:BILIBILI_USERNAME -p $env:BILIBILI_PASSWORD --write-subs --sub-langs $env:BILIBILI_SUBTITLE_LANG -o "./tmp/$($name)" --add-metadata --skip-download $url
		Write-Log "INFO" "Download file '$subs' finish"
	}

	if ((Test-Path $video) -and (Test-Path $audio) -and (Test-Path $subs)) {
		ffmpeg -i $video -i $audio -i $subs -c:v copy -c:a copy -c:s srt -disposition:s:0 default "../$($name).mkv"

		Remove-Item $video
		Remove-Item $audio
		Remove-Item $subs
		Write-Log "INFO" "File '$video', '$audio', '$subs' merged"
		Write-Log "INFO" "File '$video' deleted"
		Write-Log "INFO" "File '$audio' deleted"
		Write-Log "INFO" "File '$subs' deleted"
		Write-Log "INFO" "==============FINISH=============="
	}
	else {
		Write-Log "ERROR" "Download file is not complete, run again."
		Write-Log "ERROR" "==============ERROR=============="
	}
}
