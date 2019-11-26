﻿param(
    [string] $StagingName, 
    [string] $StoreName,
    $AzureBlobName,
    $AzureBlobKey,
    $WebAppName,
    $ResourceGroupName,
    $SubscriptionID
)

$ErrorActionPreference = "Stop"

$Path2Zip = Get-Childitem -Recurse -Path "${env:WORKSPACE}\artifacts\" -File -Include artifact.zip

# Unzip Theme Zip File
$Path = "${env:WORKSPACE}\artifacts\" + [System.IO.Path]::GetFileNameWithoutExtension($Path2Zip)

# Upload Zip File to Azure
$ConnectionString = "DefaultEndpointsProtocol=https;AccountName={0};AccountKey={1};EndpointSuffix=core.windows.net"
if ($StagingName -eq "deploy" -or $StagingName -eq "dev-vc-new-design"){
    $ConnectionString = $ConnectionString -f $AzureBlobName, $AzureBlobKey
}
$BlobContext = New-AzureStorageContext -ConnectionString $ConnectionString

$AzureBlobName = "$StoreName"
$SlotName = "staging"

$Now = Get-Date -format yyyyMMdd-HHmmss
$DestContainer = $AzureBlobName + "-" + $Now

$ApplicationID ="${env:AzureAppID}"
$APIKey = ConvertTo-SecureString "${env:AzureAPIKey}" -AsPlainText -Force
$psCred = New-Object System.Management.Automation.PSCredential($ApplicationID, $APIKey)
$TenantID = "${env:AzureTenantID}"

Add-AzureRmAccount -Credential $psCred -TenantId $TenantID -ServicePrincipal
Select-AzureRmSubscription -SubscriptionId $SubscriptionID

$DestWebAppName = $WebAppName
$DestResourceGroupName = $ResourceGroupName

Stop-AzureRmWebAppSlot -ResourceGroupName $DestResourceGroupName -Name $DestWebAppName -Slot $SlotName

New-AzureStorageContainer -Name $DestContainer -Context $BlobContext -Permission Container
Get-AzureStorageBlob -Container $StoreName -Context $BlobContext | Start-AzureStorageBlobCopy -DestContainer "$DestContainer" -Force

Write-Host "Remove from $StoreName"
if ($StagingName -eq "deploy"){
    Get-AzureStorageBlob -Blob ("Pages/vccom/docs/*") -Container $AzureBlobName -Context $BlobContext | ForEach-Object { Remove-AzureStorageBlob -Blob $_.Name -Container $AzureBlobName -Context $BlobContext } -ErrorAction Continue
}
elseif ($StagingName -eq "dev-vc-new-design"){
    Get-AzureStorageBlob -Blob ("Themes/vccom/default/*") -Container $AzureBlobName -Context $BlobContext | ForEach-Object { Remove-AzureStorageBlob -Blob $_.Name -Container $AzureBlobName -Context $BlobContext } -ErrorAction Continue
}

Write-Host "Upload to $StoreName"
if ($StagingName -eq "deploy"){
    Get-ChildItem -File -Recurse $Path | ForEach-Object { Set-AzureStorageBlobContent -File $_.FullName -Blob ("Pages/vccom/" + (([System.Uri]("$Path/")).MakeRelativeUri([System.Uri]($_.FullName))).ToString()) -Container $AzureBlobName -Context $BlobContext }
}
elseif ($StagingName -eq "dev-vc-new-design"){
    Get-ChildItem -File -Recurse $Path | ForEach-Object { Set-AzureStorageBlobContent -File $_.FullName -Blob ("Themes/vccom/" + (([System.Uri]("$Path/")).MakeRelativeUri([System.Uri]($_.FullName))).ToString()) -Container $AzureBlobName -Context $BlobContext }
}

Write-Output "Restarting web site $DestWebAppName slot $SlotName"
Start-AzureRmWebAppSlot -ResourceGroupName $DestResourceGroupName -Name $DestWebAppName -Slot $SlotName
Start-Sleep -s 66

Write-Output "Switching $DestWebAppName slot"
Switch-AzureRmWebAppSlot -Name $DestWebAppName -ResourceGroupName $DestResourceGroupName -SourceSlotName "staging" -DestinationSlotName "production"

Stop-AzureRmWebAppSlot -ResourceGroupName $DestResourceGroupName -Name $DestWebAppName -Slot $SlotName
