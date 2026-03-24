# Export-SharePointListData.ps1
# This script exports list items, attachments, comments, and metadata from a SharePoint list to JSON and downloads attachments.


# ==========================
# CONFIGURATION
# ==========================
$OutputFolder = ".\debug_batches"

$sourceList = "SourceList"
$sourceSite = "https://tenant.sharepoint.com/sites/Source"
$clientId = "00000000-0000-0000-0000-000000000000"  # Replace with your Azure AD app client ID

# For testing only: limit number of items exported. Set to 0 for no limit.
$MaxItems = 0

# Install-Module PnP.PowerShell -Scope CurrentUser if not installed

# Connect to source site
$connection = Connect-PnPOnline -Url $SourceSiteUrl -Interactive -ReturnConnection -ClientId $clientId

# Create output folder if not exists
if (!(Test-Path -Path $OutputFolder)) {
    New-Item -ItemType Directory -Path $OutputFolder | Out-Null
}

# Create attachments subfolder
$attachmentsFolder = Join-Path $OutputFolder "Attachments"
if (!(Test-Path -Path $attachmentsFolder)) {
    New-Item -ItemType Directory -Path $attachmentsFolder | Out-Null
}

# Get all list items with paging
$pageSize = 2000
$exportedData = @()
$position = $null
$totalProcessed = 0

# ==========================
# EXPORT ONLY THE SELECTED LIST
# ==========================
do {
    # Workaround: use ScriptBlock to preserve paging position for large lists.
    $items = Get-PnPListItem -List $SourceListName -PageSize $pageSize -Includes AttachmentFiles -Connection $connection -ScriptBlock { param($items) $items }

    if (!$items -or $items.Count -eq 0) { break }

    foreach ($item in $items) {
    Write-Host "Processing item ID: $($item.Id)" -ForegroundColor Cyan

    # Collect field values (excluding system fields)
    $fieldValues = @{}
    foreach ($field in $item.FieldValues.Keys) {
        if ($field -notin @("Id", "Attachments", "FileRef", "FileDirRef", "Created", "Author", "Modified", "Editor")) {
            $fieldValues[$field] = $item[$field]
        }
    }

    # Collect metadata
    $metadata = @{
        Created   = $item["Created"]
        AuthorId  = $item["Author"].LookupId
        Modified  = $item["Modified"]
        EditorId  = $item["Editor"].LookupId
    }

    # Download attachments
    $attachments = @()
    if ($item.AttachmentFiles.Count -gt 0) {
        Write-Host "  Downloading $($item.AttachmentFiles.Count) attachments..." -ForegroundColor Yellow
        $itemFolder = Join-Path $attachmentsFolder $item.Id.ToString()
        if (!(Test-Path -Path $itemFolder)) {
            New-Item -ItemType Directory -Path $itemFolder | Out-Null
        }

        foreach ($att in $item.AttachmentFiles) {
            $filePath = Join-Path $itemFolder $att.FileName
            Get-PnPFile -Url $att.ServerRelativeUrl -Path $itemFolder -FileName $att.FileName -AsFile -Connection $connection -Force
            $attachments += @{
                FileName = $att.FileName
                LocalPath = $filePath
            }
            Write-Host "    Saved attachment: $($att.FileName)" -ForegroundColor Green
        }
    }

    # Get comments
    $comments = Get-PnPListItemComment -List $SourceListName -Identity $item.Id -Connection $connection
    $commentData = @()
    foreach ($comment in $comments) {
        $commentData += @{
            Text            = $comment.Text
            AuthorDisplayName = $comment.Author.Title
            Created         = $comment.Created
        }
    }

    # Create item object
    $itemData = @{
        Id          = $item.Id
        FieldValues = $fieldValues
        Metadata    = $metadata
        Attachments = $attachments
        Comments    = $commentData
    }

    $exportedData += $itemData
    $totalProcessed++

    if (($MaxItems -gt 0) -and ($totalProcessed -ge $MaxItems)) {
        Write-Host "Reached MaxItems ($MaxItems), stopping export." -ForegroundColor Yellow
        break
    }
    }

    if (($MaxItems -gt 0) -and ($totalProcessed -ge $MaxItems)) {
        break
    }

    $position = $items.ListItemCollectionPosition
} while ($position)

# Save to JSON
$jsonPath = Join-Path $OutputFolder "ListData.json"
$exportedData | ConvertTo-Json -Depth 10 | Out-File $jsonPath

Write-Host "Export completed. Data saved to $jsonPath" -ForegroundColor Green