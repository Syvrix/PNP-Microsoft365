# Install PnP if not installed
# Install-Module PnP.PowerShell -Scope CurrentUser

# ---------- CONFIG ----------
$sourceSite = "https://tenant.sharepoint.com/sites/SourceSite"
$targetSite = "https://tenant.sharepoint.com/sites/TargetSite"

$sourceList = "SourceList"
$targetList = "TargetList"
# ----------------------------

# Connect to both sites
Connect-PnPOnline -Url $sourceSite -Interactive
$sourceItems = Get-PnPListItem -List $sourceList -PageSize 2000

Connect-PnPOnline -Url $targetSite -Interactive

foreach ($item in $sourceItems) {
    Write-Host "Processing item ID: $($item.Id)" -ForegroundColor Cyan

    # 1. Copy all field values except system-internal fields
    $fieldValues = @{}
    foreach ($field in $item.FieldValues.Keys) {
        if ($field -notin @("Id", "Attachments", "FileRef", "FileDirRef",
                            "Created", "Author", "Modified", "Editor")) {

            $fieldValues[$field] = $item[$field]
        }
    }

    # 2. Create the new item
    $newItem = Add-PnPListItem -List $targetList -Values $fieldValues

    # 3. Copy attachments
    if ($item.AttachmentFiles.Count -gt 0) {
        Write-Host " Copying attachments..."

        foreach ($att in $item.AttachmentFiles) {
            $bytes = Get-PnPFile -Url $att.ServerRelativeUrl -AsByteArray
            Add-PnPAttachment -List $targetList -Identity $newItem.Id -FileName $att.FileName -Content $bytes
        }
    }

    # 4. Copy modern comments
    $comments = Get-PnPListItemComment -List $sourceList -Item $item.Id
    foreach ($comment in $comments) {
        Add-PnPListItemComment -List $targetList -Item $newItem.Id -Text $comment.Text | Out-Null
    }

    # 5. Copy system metadata (Created, Modified, Author, Editor)
    Set-PnPListItem -List $targetList -Identity $newItem.Id `
        -Values @{
            "Created"=$item.FieldValues["Created"];
            "Author" =$item.FieldValues["Author"];
            "Modified"=$item.FieldValues["Modified"];
            "Editor" =$item.FieldValues["Editor"];
        } -SystemUpdate

    Write-Host " → Item $($item.Id) copied to $($newItem.Id)" -ForegroundColor Green
}

Write-Host "DONE!" -ForegroundColor Yellow