# Synthesises the Momentum UI sound set as 16-bit mono 44.1 kHz WAV files.
# Design brief: soft, short, non-arcade. Nothing over ~1.3 s, nothing harsh.

param([string]$OutDir)

$SR = 44100
$rand = New-Object System.Random 20260730

function New-Buffer([double]$seconds) {
    return New-Object 'double[]' ([int]($SR * $seconds))
}

# Additive sine partial with a short attack and exponential decay tail.
function Add-Partial {
    param(
        [double[]]$Buf,
        [double]$Freq,
        [double]$Amp,
        [double]$Start,
        [double]$Dur,
        [double]$Attack = 0.004,
        [double]$Tau = 0.12,
        [double]$Detune = 0.0
    )
    $i0 = [int]($Start * $SR)
    $n = [int]($Dur * $SR)
    $twoPiOverSr = 2.0 * [Math]::PI / $SR
    for ($i = 0; $i -lt $n; $i++) {
        $idx = $i0 + $i
        if ($idx -ge $Buf.Length) { break }
        $t = $i / [double]$SR
        if ($t -lt $Attack) { $env = $t / $Attack }
        else { $env = [Math]::Exp(-($t - $Attack) / $Tau) }
        $f = $Freq + $Detune * $t
        $Buf[$idx] += $Amp * $env * [Math]::Sin($twoPiOverSr * $f * $idx)
    }
}

# Frequency-swept sine: the basis for pick-up, drop and whoosh gestures.
function Add-Sweep {
    param(
        [double[]]$Buf,
        [double]$F0,
        [double]$F1,
        [double]$Amp,
        [double]$Start,
        [double]$Dur,
        [double]$Attack = 0.006,
        [double]$Release = 0.05
    )
    $i0 = [int]($Start * $SR)
    $n = [int]($Dur * $SR)
    $phase = 0.0
    for ($i = 0; $i -lt $n; $i++) {
        $idx = $i0 + $i
        if ($idx -ge $Buf.Length) { break }
        $t = $i / [double]$SR
        $p = $t / $Dur
        # Exponential glide reads more natural than a linear one.
        $f = $F0 * [Math]::Pow($F1 / $F0, $p)
        $phase += 2.0 * [Math]::PI * $f / $SR
        $env = 1.0
        if ($t -lt $Attack) { $env = $t / $Attack }
        elseif ($t -gt ($Dur - $Release)) { $env = [Math]::Max(0.0, ($Dur - $t) / $Release) }
        $Buf[$idx] += $Amp * $env * [Math]::Sin($phase)
    }
}

# Filtered noise burst - used for the whoosh and to give clicks some body.
function Add-Noise {
    param(
        [double[]]$Buf,
        [double]$Amp,
        [double]$Start,
        [double]$Dur,
        [double]$LpAlpha = 0.25,
        [double]$HpAlpha = 0.02,
        [double]$Attack = 0.03
    )
    $i0 = [int]($Start * $SR)
    $n = [int]($Dur * $SR)
    $lp = 0.0
    $dc = 0.0
    for ($i = 0; $i -lt $n; $i++) {
        $idx = $i0 + $i
        if ($idx -ge $Buf.Length) { break }
        $t = $i / [double]$SR
        $white = ($rand.NextDouble() * 2.0) - 1.0
        $lp = $lp + $LpAlpha * ($white - $lp)      # one-pole low pass
        $dc = $dc + $HpAlpha * ($lp - $dc)         # subtract slow mean -> band pass
        $band = $lp - $dc
        $p = $t / $Dur
        # Bell-shaped envelope so the burst swells and fades, never clicks.
        $env = [Math]::Sin([Math]::PI * $p)
        if ($t -lt $Attack) { $env *= ($t / $Attack) }
        $Buf[$idx] += $Amp * $env * $band
    }
}

function Save-Wav {
    param([double[]]$Buf, [string]$Path, [double]$Peak = 0.82)

    # Normalise, then apply a 4 ms fade-out so no file ends on a discontinuity.
    $max = 0.0
    foreach ($s in $Buf) { $a = [Math]::Abs($s); if ($a -gt $max) { $max = $a } }
    if ($max -lt 1e-9) { $max = 1.0 }
    $gain = $Peak / $max

    $fade = [int](0.004 * $SR)
    $len = $Buf.Length
    $bytes = New-Object 'byte[]' ($len * 2)
    for ($i = 0; $i -lt $len; $i++) {
        $v = $Buf[$i] * $gain
        if ($i -ge ($len - $fade)) { $v *= ($len - $i) / [double]$fade }
        $s = [int]([Math]::Round($v * 32767.0))
        if ($s -gt 32767) { $s = 32767 }
        if ($s -lt -32768) { $s = -32768 }
        $u = [uint16]([int16]$s -band 0xFFFF)
        $bytes[$i * 2] = [byte]($u -band 0xFF)
        $bytes[$i * 2 + 1] = [byte](($u -shr 8) -band 0xFF)
    }

    $dataLen = $bytes.Length
    $ms = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter($ms)
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes('RIFF'))
    $bw.Write([int](36 + $dataLen))
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes('WAVE'))
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes('fmt '))
    $bw.Write([int]16)
    $bw.Write([int16]1)          # PCM
    $bw.Write([int16]1)          # mono
    $bw.Write([int]$SR)
    $bw.Write([int]($SR * 2))    # byte rate
    $bw.Write([int16]2)          # block align
    $bw.Write([int16]16)         # bits per sample
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes('data'))
    $bw.Write([int]$dataLen)
    $bw.Write($bytes)
    $bw.Flush()
    [System.IO.File]::WriteAllBytes($Path, $ms.ToArray())
    $bw.Dispose()
    $ms.Dispose()
    Write-Output ("  {0,-18} {1,6} bytes" -f (Split-Path $Path -Leaf), (Get-Item $Path).Length)
}

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }
Write-Output "Synthesising sound set -> $OutDir"

# --- tap: soft click -------------------------------------------------------
$b = New-Buffer 0.06
Add-Partial -Buf $b -Freq 2100 -Amp 0.5 -Start 0 -Dur 0.05 -Attack 0.001 -Tau 0.012
Add-Noise   -Buf $b -Amp 0.18 -Start 0 -Dur 0.02 -LpAlpha 0.5 -HpAlpha 0.05 -Attack 0.001
Save-Wav -Buf $b -Path (Join-Path $OutDir 'tap.wav') -Peak 0.45

# --- pickup: gentle lift ---------------------------------------------------
$b = New-Buffer 0.16
Add-Sweep -Buf $b -F0 440 -F1 700 -Amp 0.6 -Start 0 -Dur 0.13 -Attack 0.012 -Release 0.05
Add-Partial -Buf $b -Freq 1400 -Amp 0.12 -Start 0 -Dur 0.1 -Attack 0.01 -Tau 0.05
Save-Wav -Buf $b -Path (Join-Path $OutDir 'pickup.wav') -Peak 0.55

# --- drop: pop -------------------------------------------------------------
$b = New-Buffer 0.13
Add-Sweep -Buf $b -F0 760 -F1 260 -Amp 0.75 -Start 0 -Dur 0.09 -Attack 0.002 -Release 0.04
Add-Partial -Buf $b -Freq 180 -Amp 0.3 -Start 0 -Dur 0.1 -Attack 0.002 -Tau 0.035
Save-Wav -Buf $b -Path (Join-Path $OutDir 'drop.wav') -Peak 0.65

# --- create: tick ----------------------------------------------------------
$b = New-Buffer 0.05
Add-Partial -Buf $b -Freq 1480 -Amp 0.5 -Start 0 -Dur 0.04 -Attack 0.001 -Tau 0.014
Add-Partial -Buf $b -Freq 2960 -Amp 0.12 -Start 0 -Dur 0.03 -Attack 0.001 -Tau 0.01
Save-Wav -Buf $b -Path (Join-Path $OutDir 'create.wav') -Peak 0.5

# --- board_created: soft success (C6 -> E6) --------------------------------
$b = New-Buffer 0.36
Add-Partial -Buf $b -Freq 1046.5 -Amp 0.5 -Start 0.00 -Dur 0.22 -Attack 0.006 -Tau 0.09
Add-Partial -Buf $b -Freq 2093.0 -Amp 0.14 -Start 0.00 -Dur 0.18 -Attack 0.006 -Tau 0.06
Add-Partial -Buf $b -Freq 1318.5 -Amp 0.5 -Start 0.09 -Dur 0.26 -Attack 0.006 -Tau 0.11
Add-Partial -Buf $b -Freq 2637.0 -Amp 0.12 -Start 0.09 -Dur 0.2  -Attack 0.006 -Tau 0.07
Save-Wav -Buf $b -Path (Join-Path $OutDir 'board_created.wav') -Peak 0.6

# --- start: whoosh ---------------------------------------------------------
$b = New-Buffer 0.28
Add-Noise -Buf $b -Amp 0.9 -Start 0 -Dur 0.24 -LpAlpha 0.16 -HpAlpha 0.012 -Attack 0.05
Add-Sweep -Buf $b -F0 260 -F1 620 -Amp 0.16 -Start 0.01 -Dur 0.2 -Attack 0.05 -Release 0.09
Save-Wav -Buf $b -Path (Join-Path $OutDir 'start.wav') -Peak 0.5

# --- complete: success chime (E5 - G#5 - B5, major triad) ------------------
$b = New-Buffer 0.75
Add-Partial -Buf $b -Freq 659.3  -Amp 0.5  -Start 0.00 -Dur 0.5  -Attack 0.005 -Tau 0.16
Add-Partial -Buf $b -Freq 830.6  -Amp 0.48 -Start 0.09 -Dur 0.5  -Attack 0.005 -Tau 0.17
Add-Partial -Buf $b -Freq 987.8  -Amp 0.46 -Start 0.18 -Dur 0.55 -Attack 0.005 -Tau 0.22
Add-Partial -Buf $b -Freq 1975.5 -Amp 0.10 -Start 0.18 -Dur 0.4  -Attack 0.005 -Tau 0.12
Save-Wav -Buf $b -Path (Join-Path $OutDir 'complete.wav') -Peak 0.68

# --- timer_start: subtle tone ----------------------------------------------
$b = New-Buffer 0.3
Add-Partial -Buf $b -Freq 523.3  -Amp 0.5  -Start 0 -Dur 0.28 -Attack 0.03 -Tau 0.13
Add-Partial -Buf $b -Freq 1046.5 -Amp 0.10 -Start 0 -Dur 0.2  -Attack 0.03 -Tau 0.08
Save-Wav -Buf $b -Path (Join-Path $OutDir 'timer_start.wav') -Peak 0.5

# --- pause: soft low click -------------------------------------------------
$b = New-Buffer 0.09
Add-Partial -Buf $b -Freq 330 -Amp 0.55 -Start 0 -Dur 0.08 -Attack 0.003 -Tau 0.028
Save-Wav -Buf $b -Path (Join-Path $OutDir 'pause.wav') -Peak 0.45

# --- resume: gentle tick ---------------------------------------------------
$b = New-Buffer 0.12
Add-Partial -Buf $b -Freq 622 -Amp 0.45 -Start 0.00 -Dur 0.05 -Attack 0.002 -Tau 0.022
Add-Partial -Buf $b -Freq 932 -Amp 0.45 -Start 0.05 -Dur 0.07 -Attack 0.002 -Tau 0.03
Save-Wav -Buf $b -Path (Join-Path $OutDir 'resume.wav') -Peak 0.48

# --- timer_done: pleasant bell ---------------------------------------------
$b = New-Buffer 1.4
Add-Partial -Buf $b -Freq 880.0  -Amp 0.60 -Start 0 -Dur 1.35 -Attack 0.004 -Tau 0.45
Add-Partial -Buf $b -Freq 1760.0 -Amp 0.22 -Start 0 -Dur 1.1  -Attack 0.004 -Tau 0.30
Add-Partial -Buf $b -Freq 2640.0 -Amp 0.10 -Start 0 -Dur 0.8  -Attack 0.004 -Tau 0.18
# Slight inharmonic partial: what makes a bell read as a bell, not a sine.
Add-Partial -Buf $b -Freq 1197.0 -Amp 0.08 -Start 0 -Dur 0.9  -Attack 0.004 -Tau 0.25
Save-Wav -Buf $b -Path (Join-Path $OutDir 'timer_done.wav') -Peak 0.72

# --- tick: last-ten-seconds pulse (very quiet) -----------------------------
$b = New-Buffer 0.04
Add-Partial -Buf $b -Freq 1000 -Amp 0.4 -Start 0 -Dur 0.03 -Attack 0.001 -Tau 0.008
Save-Wav -Buf $b -Path (Join-Path $OutDir 'tick.wav') -Peak 0.3

# --- xp: coin sparkle ------------------------------------------------------
$b = New-Buffer 0.3
Add-Partial -Buf $b -Freq 1568.0 -Amp 0.45 -Start 0.00 -Dur 0.12 -Attack 0.002 -Tau 0.045
Add-Partial -Buf $b -Freq 2093.0 -Amp 0.45 -Start 0.05 -Dur 0.22 -Attack 0.002 -Tau 0.09
Add-Partial -Buf $b -Freq 3136.0 -Amp 0.14 -Start 0.05 -Dur 0.16 -Attack 0.002 -Tau 0.06
Save-Wav -Buf $b -Path (Join-Path $OutDir 'xp.wav') -Peak 0.55

# --- level_up: short fanfare (C5 - E5 - G5 - C6) ---------------------------
$b = New-Buffer 1.0
Add-Partial -Buf $b -Freq 523.3  -Amp 0.42 -Start 0.00 -Dur 0.3  -Attack 0.004 -Tau 0.11
Add-Partial -Buf $b -Freq 659.3  -Amp 0.42 -Start 0.09 -Dur 0.3  -Attack 0.004 -Tau 0.11
Add-Partial -Buf $b -Freq 784.0  -Amp 0.42 -Start 0.18 -Dur 0.3  -Attack 0.004 -Tau 0.11
Add-Partial -Buf $b -Freq 1046.5 -Amp 0.55 -Start 0.27 -Dur 0.7  -Attack 0.004 -Tau 0.30
Add-Partial -Buf $b -Freq 1568.0 -Amp 0.18 -Start 0.27 -Dur 0.55 -Attack 0.004 -Tau 0.22
Add-Partial -Buf $b -Freq 2093.0 -Amp 0.09 -Start 0.27 -Dur 0.45 -Attack 0.004 -Tau 0.16
Save-Wav -Buf $b -Path (Join-Path $OutDir 'level_up.wav') -Peak 0.75

# --- achievement: sparkle --------------------------------------------------
$b = New-Buffer 0.7
$notes = @(1318.5, 1760.0, 2093.0, 2637.0, 2093.0, 2637.0)
for ($i = 0; $i -lt $notes.Length; $i++) {
    $amp = 0.34 - ($i * 0.02)
    Add-Partial -Buf $b -Freq $notes[$i] -Amp $amp -Start (0.045 * $i) -Dur 0.4 -Attack 0.002 -Tau 0.13
}
Save-Wav -Buf $b -Path (Join-Path $OutDir 'achievement.wav') -Peak 0.62

# --- notify: clean bell ----------------------------------------------------
$b = New-Buffer 0.7
Add-Partial -Buf $b -Freq 1318.5 -Amp 0.55 -Start 0.00 -Dur 0.6  -Attack 0.004 -Tau 0.22
Add-Partial -Buf $b -Freq 1975.5 -Amp 0.25 -Start 0.07 -Dur 0.55 -Attack 0.004 -Tau 0.20
Save-Wav -Buf $b -Path (Join-Path $OutDir 'notify.wav') -Peak 0.6

Write-Output "Done."
