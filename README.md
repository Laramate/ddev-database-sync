<p align="center" style="background: white; padding: 40px 20px 20px 20px"><a href="https://laramate.de" target="_blank"><img src="https://laramate.de/laramate.webp" width="200" alt="Laravel Logo"></a></p>

# Laramate DDEV Database Sync

Copies production database data from a remote server to local workspace.

## Setup
You need to add following variables to you local .env file:

- REMOTE_USER
- REMOTE_HOST
- REMOTE_PATH_TO_PROJECT
- REMOTE_DB_DATABASE

Start your application with ddev start or ddev launch first. Then you can 
simply run this custom command. Only works with mysql database.

## Usage
```bash
ddev db-to-local [OPTIONS]
```

## Options
| Parameter  | Description        |
|------------|--------------------|
| --help, -h | Prints  help page. |