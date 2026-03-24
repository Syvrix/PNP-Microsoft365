# Export-SharePointListData.ps1
# This script exports list items, attachments, comments, and metadata from a SharePoint list to JSON and downloads attachments.

# Load configuration from .env file
$envFile = ".\.env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^([^=]+)=(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            # Strip surrounding quotes if present
            if ($value -match '^"(.*)"$') {
                $value = $matches[1]
            } elseif ($value -match "^'(.*)'$") {
                $value = $matches[1]
            }
            Set-Variable -Name $key -Value $value
        }
    }
    Write-Host "Configuration loaded from .env file" -ForegroundColor Green
} else {
    Write-Warning ".env file not found. Using default values."
}

# ==========================
# CONFIGURATION
# ==========================
$OutputFolder = ".\debug_batches"

$sourceList = $SOURCE_LIST
$sourceSite = $SOURCE_SITE
$clientId = $CLIENT_ID

# For testing only: limit number of items exported. Set to 0 for no limit.
$MaxItems = 0

# Install-Module PnP.PowerShell -Scope CurrentUser if not installed

# Connect to source site
$connection = Connect-PnPOnline -Url $sourceSite -Interactive -ReturnConnection -ClientId $clientId

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
    $items = Get-PnPListItem -List $sourceList -PageSize $pageSize -Includes AttachmentFiles -Connection $connection -ScriptBlock { param($items) $items }

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
    $comments = Get-PnPListItemComment -List $sourceList -Identity $item.Id -Connection $connection
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