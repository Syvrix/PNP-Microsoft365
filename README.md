# PnP Microsoft 365 List Migration Scripts

This repository contains PowerShell scripts for exporting and importing SharePoint list data, including attachments and comments. It is designed to simplify migration scenarios and support cases where a full list copy is needed from one site to another.

## Supported Features
- Export list items to JSON
- Export item attachments to local disk
- Preserve comments and include author timestamps

## Setup
1. Create or copy a `.env` file in the script folder.
2. Use the provided `.env.example` as a template and set values for:
   - `SOURCE_SITE`
   - `TARGET_SITE`
   - `SOURCE_LIST`
   - `TARGET_LIST`
   - `CLIENT_ID`
3. Ensure the `.env` file is excluded from source control (it is already ignored by git).

Example `.env` format (See the example file)

## Usage
### 1. Export source data
Run `StoreListItems.ps1`:
- Exports list items and schema data to `ListData.json`
    - Captures comments and metadata
- Downloads attachments under `/Attachments`

## Authorization
- Requires `PnP.PowerShell` module.
- Use an Azure AD app registration with read write site permissions.
- Scripts prompt for interactive login via browser (`Connect-PnPOnline -Interactive`).

## Requirements
- PowerShell 7+ (recommended)
- NuGet package provider
- Install PnP.PowerShell:
  ```powershell
  Install-Module PnP.PowerShell -Scope CurrentUser
  ```

## Notes
- Field names and internal field IDs should match between source and target lists for successful data mapping.
- Comments are posted by the migration account; the original author name is included in the comment text by script design.
- For large lists, adjust `$MaxItems` in `StoreListItems.ps1` for safe testing.

## Credits
Created by Syvrix (intern)