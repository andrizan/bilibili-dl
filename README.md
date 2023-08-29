
## bilibili-dl
Download tools for [bilibili.tv](https://www.bilibili.tv)
### Requirement
* [PowerShell](https://github.com/PowerShell/PowerShell)
* [FFmpeg](https://ffmpeg.org/download.html)
* [yt-dlp](https://github.com/yt-dlp/yt-dlp)
* [aria2c](https://github.com/aria2/aria2)

### Usage
```
.\dl.ps1 "https://example.com/video/davsfre223wde" "Title"
```

### Download Result
```
* resolution | .env=480
* format video | mkv (remux)
* format audio | opus (encode)
* format subtitles | srt | .env=en
```

### File Playlist
Download script anime Detective Conan (Case Closed).
#### Usage
- login account from browser (chrome/firefox)
- exp url : `https://www.bilibili.tv/id/play/1022690/10655935?bstar_from=bstar-web.pgc-video-detail.episode.0`
- 10655935 = eps_id
```
.\playlist.ps1 -eps_id 11004093,11004145,11004208
```
