# Install-Module PnP.PowerShell -Scope CurrentUser
# Connect to source
$sourceSite = "https://tenant.sharepoint.com/sites/Source"
$targetSite = "https://tenant.sharepoint.com/sites/Target"
$sourceList = "SourceList"
$targetList = "TargetList"

$pageSize = 500   # Optimal for 10k items
$logFile = "migration_log.csv"

Connect-PnPOnline -Url $sourceSite -Interactive

$position = $null
$batchCounter = 1

do {
    # Get 1 page
    $items = Get-PnPListItem -List $sourceList -PageSize $pageSize -ScriptBlock { param($items) } -Position $position
    $position = $items.Position

    Connect-PnPOnline -Url $targetSite -Interactive
    $batch = New-PnPBatch

    foreach ($item in $items) {

        # Copy field values except system fields
        $values = @{}
        foreach ($field in $item.FieldValues.Keys) {
            if ($field -notin @("Id","Attachments","FileRef","FileDirRef","Created","Author","Modified","Editor")) {
                $values[$field] = $item[$field]
            }
        }

        # Add item in batch
        $newItem = Add-PnPListItem -List $targetList -Values $values -Batch $batch

        # Copy attachments
        if ($item.AttachmentFiles.Count -gt 0) {
            foreach ($att in $item.AttachmentFiles) {
                $bytes = Get-PnPFile -Url $att.ServerRelativeUrl -AsByteArray
                Add-PnPAttachment -List $targetList -Identity $newItem -FileName $att.FileName -Content $bytes -Batch $batch
            }
        }

        # Copy comments
        $comments = Get-PnPListItemComment -List $sourceList -Item $item.Id
        foreach ($comment in $comments) {
            Add-PnPListItemComment -List $targetList -Item $newItem -Text $comment.Text -Batch $batch
        }

        # Copy system metadata afterward
        Set-PnPListItem -List $targetList -Identity $newItem `
            -Values @{
                "Created"  = $item["Created"]
                "Author"   = $item["Author"]
                "Modified" = $item["Modified"]
                "Editor"   = $item["Editor"]
            } -SystemUpdate -Batch $batch

        # Log
        "$($item.Id),Pending" | Out-File $logFile -Append
    }

    Write-Host "Executing batch $batchCounter..." -ForegroundColor Cyan
    Invoke-PnPBatch -Batch $batch
    $batchCounter++

} while ($position -ne $null)

Write-Host "Migration Completed!" -ForegroundColor Green