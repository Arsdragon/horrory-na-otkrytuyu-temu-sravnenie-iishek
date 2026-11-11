param([string]$Root)
Add-Type -AssemblyName System.Speech
$out = Join-Path $Root "tools\voice_raw"
New-Item -ItemType Directory -Force $out | Out-Null
$s = New-Object System.Speech.Synthesis.SpeechSynthesizer
$s.SelectVoice("Microsoft Irina Desktop")
$s.Rate = -2
foreach ($line in Get-Content (Join-Path $Root "tools\voice_lines.txt") -Encoding UTF8) {
    if ($line -notmatch "\|") { continue }
    $p = $line.Split("|", 2)
    $s.SetOutputToWaveFile((Join-Path $out ($p[0] + ".wav")))
    $s.Speak($p[1])
}
$s.SetOutputToNull()
$s.Dispose()
"done"
