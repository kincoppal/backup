# Backup Veeam Config to AWS S3
#
# Description: Looks for Veeam config backup files and uploads
# the most recent one to a bucket in S3. 
# Created by James Davis 17/10/2018
#

Import-Module AWSPowerShell

# Variable Constants
$config = Get-Content -Raw -Path 'C:\Scripts\backup\config.json' | ConvertFrom-Json
$source = 'F:\Backup\VeeamConfigBackup'
[string]$emailBody = ""

Initialize-AWSDefaultConfiguration -AccessKey $config.AKey -SecretKey $config.SKey -Region $config.region
Set-Location $source

$emailBody = $emailBody + $(Get-Date -Format o) + "`tStart Backup Job`n"

$backupFolders = Get-ChildItem -Directory | Select-Object -Property FullName
foreach($folder in $backupFolders) {
    Set-Location $folder.FullName
    $files = Get-ChildItem '*.bco' | Sort-Object CreationTime | Select-Object -Last 1 | Select-Object -Property FullName
    foreach($file in $files){
        # check if file already exists in S3
        if(!(Get-S3Object -BucketName $config.bucket -Key $file.FullName)) {
            try {
                # upload the latest file
                $emailBody = $emailBody + $(Get-Date -Format o) + "`tUploading file: " + $file.FullName + "`n"
                Write-S3Object -BucketName $config.bucket -File $file.FullName -Key $file.FullName -CannedACLName private

            } catch {
                $emailBody = $emailBody + $(Get-Date -Format o) + "Error uploading file: $folder.FullName"
            }
        }
    }
}

$emailBody = $emailBody + $(Get-Date -Format o) + "`tEnd Backup Job`n"
$emailSubject = "Backup Veeam Config to AWS S3 Log - " + $(Get-Date -DisplayHint Date)

Send-MailMessage -To $config.emailTo -From $config.emailFrom -Subject $emailSubject -SmtpServer $config.smtpServer -Body $emailBody
