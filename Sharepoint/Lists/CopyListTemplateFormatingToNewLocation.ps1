# ==========================
# CONFIGURATION
# ==========================
$sourceSiteUrl  = "https://tenant.sharepoint.com/sites/SourceSite"
$targetSiteUrl  = "https://tenant.sharepoint.com/sites/TargetSite"

$sourceListName = "SourceListName"
$targetListName = "TargetListName"

$templatePath = ".\ListOnlyTemplate.xml"


# ==========================
# EXPORT ONLY THE SELECTED LIST
# ==========================
Connect-PnPOnline -Url $sourceSiteUrl -Interactive

Get-PnPSiteTemplate `
    -Out $templatePath `
    -Lists $sourceListName `
    -Handlers Lists, Fields, ContentTypes, Views, ListSettings `
    -ExcludeHandlers Navigation, Workflows, Security, Branding

Write-Host "List schema exported." -ForegroundColor Green


# ==========================
# IMPORT INTO TARGET SITE
# ==========================
Connect-PnPOnline -Url $targetSiteUrl -Interactive

Invoke-PnPSiteTemplate -Path $templatePath

# Rename if needed
if ($sourceListName -ne $targetListName) {
    $list = Get-PnPList -Identity $sourceListName
    Set-PnPList -Identity $list -Title $targetListName
}

Write-Host "List structure copied successfully!" -ForegroundColor Green