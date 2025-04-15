function DarkYellow($messaggio) {
    Write-Host $messaggio -ForegroundColor DarkYellow 
}

function MostraErrore($messaggio) {
    Write-Host "[ERRORE]" $messaggio -ForegroundColor Red
}

# Logo
Write-Host "        _      _  ____                 _         _    _"
Write-Host "__   __(_)  __| ||___ \  _ __    __ _ (_) _ __  | |_ (_) _ __    __ _"
Write-Host "\ \ / /| | / _  |  __) ||  _ \  / _  || ||  _ \ | __|| ||  _ \  / _  |"
Write-Host " \ V / | || (_| | / __/ | |_) || (_| || || | | || |_ | || | | || (_| |"
Write-Host "  \_/  |_| \__,_||_____|| .__/  \__,_||_||_| |_| \__||_||_| |_| \__, |"
Write-Host "                        |_|                                     |___/"
Write-Host " "

# Mostra l'elenco dei progetti esistenti
$projectsDir = ".\projects"
if (Test-Path $projectsDir) {
    $existingProjects = Get-ChildItem -Path $projectsDir -Directory | Select-Object -ExpandProperty Name
    if ($existingProjects.Count -gt 0) {
        Write-Host "Progetti esistenti:"
        $existingProjects | ForEach-Object { Write-Host "- $_" }
        Write-Host ""
    }
}

# Chiede il nome del progetto
$projectName = Read-Host "Inserisci il nome di un nuovo progetto, o aprine uno esistente (es. il_mio_progetto)"

# Crea la struttura delle cartelle
$projectDir = ".\projects\$projectName"
$tmpDir = "$projectDir\tmp"
$paletteDir = "$tmpDir\palette_output"
$frameDir = "$tmpDir\frame_output"
$finalDir = "$tmpDir\final_output"

# Se la cartella del progetto esiste già, elimina automaticamente i file temporanei
if (Test-Path $projectDir) {
    # Rimuove la cartella tmp esistente e tutte le sue sottocartelle
    if (Test-Path $tmpDir) {
        Remove-Item -Path $tmpDir -Recurse -Force
    }
}
# Crea le cartelle necessarie
New-Item -ItemType Directory -Force -Path $projectDir | Out-Null
New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null
New-Item -ItemType Directory -Force -Path $paletteDir | Out-Null
New-Item -ItemType Directory -Force -Path $frameDir | Out-Null
New-Item -ItemType Directory -Force -Path $finalDir | Out-Null

Start-Process explorer.exe -ArgumentList (Resolve-Path $projectDir).Path
Write-Host "Inserisci ora il video nella cartella: $projectDir"
Pause

# Chiede il nome del video (senza estensione)
do {
    $videoBaseName = Read-Host "Inserisci il nome del video (senza estensione, es. il_mio_video)"
    $videoInput = "$projectDir\$videoBaseName.mp4"
    if (-not (Test-Path $videoInput)) {
        Write-Host MostraErrore "Il video non esiste! Riprova."
    }
} while (-not (Test-Path $videoInput))

# Chiede la risoluzione del video
do {
    $width = Read-Host "Inserisci la larghezza desiderata del quadro (in pixel, es. 128)"
    if (-not ($width -as [int]) -or [int]$width -le 0) {
        MostraErrore "Inserisci un numero maggiore di 0."
    }
} while (-not ($width -as [int]) -or [int]$width -le 0)

$height = $width

# Chiede i frame per secondo
do {
    $fps = Read-Host "Inserisci i frame per secondo (max 20, es. 5)"
    if (-not ($fps -as [int]) -or [int]$fps -le 0 -or [int]$fps -gt 20) {
        MostraErrore "Inserisci un numero maggiore di 0 e al massimo 20."
    }
} while (-not ($fps -as [int]) -or [int]$fps -le 0 -or [int]$fps -gt 20)

# Chiede il numero massimo di colori per la palette
do {
    $maxColors = Read-Host "Inserisci il numero massimo di colori per la palette (min 5, es. 16)"
    if (-not ($maxColors -as [int]) -or [int]$maxColors -lt 5) {
        MostraErrore "Inserisci un numero maggiore o uguale a 5."
    }
} while (-not ($maxColors -as [int]) -or [int]$maxColors -lt 5)

# Ricava la durata del video
$videoDuration = [math]::Round((ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $videoInput), 2)

# Calcola i frame totali dopo il ridimensionamento
$videoTotalFramesPost = [long]([math]::Floor($videoDuration * $fps))

# Altezza totale = impilamento verticale dei frame
$finalHeight = $videoTotalFramesPost * $height

# Calcolo pixel per un singolo frame
$totalPixelsPerFrame = [long]$width * [long]$height

# Calcolo bit per pixel
$bpp = [math]::Ceiling([math]::Log($maxColors, 2))

# Calcolo dimensione di UN frame (in MB)
$frameSizeMB = ($totalPixelsPerFrame * $bpp) / 8 / 1024 / 1024

# Calcolo dimensione totale (in MB)
$totalSizeMB = [math]::Round($frameSizeMB * $videoTotalFramesPost, 2)

# Output finale
Write-Host "`nDimensioni finali: ${width}x$finalHeight"
Write-Host "Dimensioni file stimate: ~$totalSizeMB MB"

# 1. Ridimensiona il video
$resizedVideo = "$tmpDir\${videoBaseName}_resized.mp4"
Write-Host "Ridimensionamento del video..."
ffmpeg -hide_banner -loglevel panic -i $videoInput -vf "scale=${width}:${height}:flags=neighbor,setsar=1" -an -r $fps $resizedVideo

# 2. Genera le palette
Write-Host "Generazione delle palette..."
$totalFrames = [math]::Ceiling((Get-Content $resizedVideo).Length / 1000000)  # Calcola un'approssimazione dei frame totali
$progress = 0
$step = 100 / $totalFrames

ffmpeg -hide_banner -loglevel panic -hwaccel cuda -threads 6 -i $resizedVideo -filter_complex "palettegen=stats_mode=single:max_colors=$maxColors" "$paletteDir/palette_%03d.png" | ForEach-Object {
    $progress += $step
    Write-Progress -PercentComplete $progress -Status "Generazione palette" -Activity "Caricamento..." 
}

# 3. Estrai i frame
Write-Host "Estrazione dei frame..."
$totalFrames = [math]::Ceiling((Get-Content $resizedVideo).Length / 1000000)  # Calcola un'approssimazione dei frame totali
$progress = 0
$step = 100 / $totalFrames

ffmpeg -hide_banner -loglevel panic -hwaccel cuda -threads 6 -i $resizedVideo "$frameDir/frame_%03d.png" | ForEach-Object {
    $progress += $step
    Write-Progress -PercentComplete $progress -Status "Estrazione frame" -Activity "Caricamento..." 
}

# 4. Prende tutti i frame generati
$frames = Get-ChildItem -Path $frameDir -Filter "frame_*.png"

# 5. Applica la palette a ogni frame
Write-Host "Applicazione della palette ai frame..."
foreach ($frame in $frames) {
    $num = $frame.Name -replace "frame_(\d+).png",'$1'
    $outputFile = "$finalDir/final_$num.png"
    ffmpeg -hide_banner -loglevel panic -i "$frameDir/frame_$num.png" -i "$paletteDir/palette_$num.png" -filter_complex "[0:v][1:v]paletteuse" $outputFile
}

Write-Host "Processo completato!"

# 6. Calcola il frametime per il .mcmeta
$frametime = [math]::Round((1 / $fps) * 20)  # Calcola frametime in base agli fps

# 7. Crea il file .mcmeta con il frametime
$mcmetaPath = "$projectDir\$videoBaseName.png.mcmeta"
$mcmetaContent = @{
    "animation" = @{
        "interpolate" = $true
        "frametime" = $frametime
    }
}

# Scrivi il contenuto JSON nel file .mcmeta
$mcmetaContent | ConvertTo-Json -Depth 3 | Set-Content -Path $mcmetaPath -Force

Write-Host "File .mcmeta creato con frametime: $frametime"

# 8. Combina le immagini verticalmente usando lo script Python
$finalOutputDir = "$finalDir"
$outputFile = "$projectDir\$videoBaseName.png"  # Nome del file combinato, lo stesso del video

Write-Host "Combinando le immagini in un'unica immagine verticale..."

# Esegui lo script Python per combinare le immagini (assicurati che python sia installato)
$pythonScriptPath = "src\combine_images.py"  # Sostituisci con il percorso del tuo script Python

# Comando per eseguire il programma Python e attendere che il processo finisca
python $pythonScriptPath $finalOutputDir $outputFile

# Verifica che il file sia stato creato
if (Test-Path $outputFile) {
    Write-Host "Immagine combinata creata: $outputFile"
} else {
    Write-Host "Errore nella creazione dell'immagine combinata."
}

# Elimina i file temporanei
$cleanup = Read-Host "Vuoi eliminare i file temporanei? (s/n)"
if ($cleanup -eq 's') {
    Remove-Item -Path $tmpDir -Recurse -Force
    Write-Host "File temporanei eliminati"
}

# Anteprima del risultato finale
$previewScriptPath = "src\preview.py"
$previewImagePath = $outputFile

python $previewScriptPath $previewImagePath

# Pausa prima che lo script termini
Start-Sleep -Seconds 0.1