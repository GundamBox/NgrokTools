param (
    [Parameter(Mandatory = $true)][string]$port
)

$ZxingFolder = './'
$NgrokFolder = './'
$QRCodeFile = 'qrcodeTest.png'

# Start ngrok / 啟動 ngrok
$ngork_app = Start-Process -FilePath "${NgrokFolder}/ngrok.exe" -ArgumentList "http", $port -PassThru -WindowStyle Hidden
Start-Sleep 1
Write-Output "ngrok started."

# Get ngrok URL / 取得 ngrok URL
$loopCondition=$true
$retryCount = 0;
do {
    $retryCount++;
    
    $resp = Invoke-WebRequest -Uri "http://localhost:4040/api/tunnels" -Method Get
    $url = $resp | ConvertFrom-Json | Select-Object -ExpandPropert tunnels | Where-Object { $_.Proto -eq "https" } | Select-Object -ExpandProperty public_url
    
    if($url) {
        Write-Output "ngrok url: $url"
        $loopCondition = $false
    }
    else{
        Write-Output "Can not get url. Retry $retryCount"
        Start-Sleep 1
    }

    if($retryCount -eq 3 -and $loopCondition) {
        Write-Output "Can not connect ngork. Break down"
        Stop-Process -InputObject $ngork_app
        exit 1
    }
}while($loopCondition)

# Convert URL to QR code / 將 URL 轉成 QR code
Add-Type -Path "${ZxingFolder}/zxing.dll"
$writer = New-Object -TypeName ZXing.BarcodeWriter -Property @{ Format="QR_CODE" }
$bitmap = $writer.Write($url)
$bitmap.Save($QRCodeFile)

# Open QR code windows / 打開 QRCode 視窗
[void][reflection.assembly]::LoadWithPartialName("System.Windows.Forms")
$img = $bitmap

[System.Windows.Forms.Application]::EnableVisualStyles();
$form = new-object Windows.Forms.Form
$form.Text = "QRCode Viewer"
$form.Width = $img.Size.Width * 2;
$form.Height =  $img.Size.Height * 2;
$pictureBox = new-object Windows.Forms.PictureBox
$pictureBox.BackColor = [System.Drawing.Color]::Transparent
$pictureBox.Dock = [System.Windows.Forms.DockStyle]::Fill
$pictureBox.Image = $img;
$pictureBox.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::CenterImage

$form.controls.add($pictureBox)
$form.Add_Shown( { $form.Activate() } )
$form.ShowDialog() | Out-Null
$form.Dispose()

Remove-Item -Path $QRCodeFile

# Close ngrok / 關掉 ngrok
Stop-Process -InputObject $ngork_app
Write-Output "ngrok stoped."