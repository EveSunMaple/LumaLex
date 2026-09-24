$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Speech

$sentences = @(
    'The market has already priced in the cut.',
    'Investors are waiting for the central bank''s next decision.',
    'Some analysts expect a gradual recovery.'
)
$voice = New-Object System.Speech.Synthesis.SpeechSynthesizer
$voice.SelectVoice('Microsoft Zira Desktop')
$format = New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo(
    16000,
    [System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen,
    [System.Speech.AudioFormat.AudioChannel]::Mono
)
$target = Join-Path $PSScriptRoot '..\LumaLex\Resources\Demo.wav'
$directory = Split-Path -Parent $target
New-Item -ItemType Directory -Path $directory -Force | Out-Null

function Read-PcmData([string] $path) {
    $bytes = [System.IO.File]::ReadAllBytes($path)
    $offset = 12
    while ($offset + 8 -le $bytes.Length) {
        $tag = [System.Text.Encoding]::ASCII.GetString($bytes, $offset, 4)
        $size = [System.BitConverter]::ToInt32($bytes, $offset + 4)
        if ($tag -eq 'data') {
            $pcm = New-Object byte[] $size
            [System.Array]::Copy($bytes, $offset + 8, $pcm, 0, $size)
            return ,$pcm
        }
        $offset += 8 + $size + ($size % 2)
    }
    throw "WAV data chunk not found: $path"
}

$pcm = New-Object 'System.Collections.Generic.List[byte]'
$timeline = @()
for ($index = 0; $index -lt $sentences.Count; $index++) {
    $temp = Join-Path $env:TEMP "lumalex-demo-$index.wav"
    try {
        $voice.SetOutputToWaveFile($temp, $format)
        $voice.Speak($sentences[$index])
        $voice.SetOutputToNull()
        $start = $pcm.Count / 32000.0
        $pcm.AddRange([byte[]](Read-PcmData $temp))
        $end = $pcm.Count / 32000.0
        $timeline += [pscustomobject]@{ start = $start; end = $end; english = $sentences[$index] }
        $pcm.AddRange([byte[]](New-Object byte[] 14400))
    } finally {
        $voice.SetOutputToNull()
        Remove-Item -LiteralPath $temp -ErrorAction SilentlyContinue
    }
}

$stream = [System.IO.File]::Open($target, [System.IO.FileMode]::Create)
$writer = New-Object System.IO.BinaryWriter($stream)
try {
    $writer.Write([System.Text.Encoding]::ASCII.GetBytes('RIFF'))
    $writer.Write([int](36 + $pcm.Count))
    $writer.Write([System.Text.Encoding]::ASCII.GetBytes('WAVEfmt '))
    $writer.Write([int]16)
    $writer.Write([int16]1)
    $writer.Write([int16]1)
    $writer.Write([int]16000)
    $writer.Write([int]32000)
    $writer.Write([int16]2)
    $writer.Write([int16]16)
    $writer.Write([System.Text.Encoding]::ASCII.GetBytes('data'))
    $writer.Write([int]$pcm.Count)
    $writer.Write($pcm.ToArray())
} finally {
    $writer.Dispose()
}

$timeline | ConvertTo-Json -Depth 3
