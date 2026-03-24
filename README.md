# Introduction
This repository contains powershell scripts used to facilitate Microsoft 365 tasks that could be very complex or not available through traditional means not supported by Microsoft.

Use case scenarios is like making a identical microsoft list or moving it to a new sharepoint site.

Currently Supports:
- Exporting All items to a Json file-
- Exporting Attatchments attatched to the item.

## Instructions
.env file is used for "secrets" located in each folder for the type of scripts.
Rename .env.example to .env to make it work. (.env is ignored by git and will be lost during push)

### Authorization
- A client app on azure needs to be setup with read rights.
- The only configuration that needs to be entered is list names, Sharepoint site name and Client ID.
- Auhorization will prompt the user to login in a web browser to create a session to access the list.

### Requirements
1. Powershell
2. PackageProvider NuGet
3. Installing PnP PowerShell
    - Registering your own Entra ID Application 
    - Connecting and authenticating
    - https://pnp.github.io/powershell/


## Credits
Created by Syvrix during internship.