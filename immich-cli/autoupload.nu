#!/usr/bin/env nu
use std log

# Get the modification time of the most recently modified file in the given directory.
def latest_file_modified_time [
    directory: path
    file_type: string = image  # Only check files which have this mime type
] {
    ls --all --mime-type $"($directory)" | where type starts-with $file_type | sort-by --reverse modified | first | get modified
}

# Watch for new pictures in the given directory and upload them to Immich.
def main [
    directory # The directory to watch
    --file-type = "image" # The mime type of the files to watch
    --immich-instance-url = "https://immich.jwillikers.io/api" # The URL of the Immich instance
    --immich-cli-tag = "latest" # The tag of the Immich CLI container image
    --systemd-notify # Enable systemd-notify support for running as a systemd service
    --wait-time = 3min  # The amount of time to wait after the last file has appeared before uploading
] {
    if $systemd_notify {
        ^/usr/bin/systemd-notify --ready $"--status='Watching for ($file_type) files in ($directory)'"
    }
    watch --glob $file_type $directory { |op, path, new_path| 
        if $op == "Create" {
            log info $"File ($path) created"
            sleep $wait_time
            let last_modified = latest_file_modified_time $directory $file_type
            while (date now) - $last_modified < $wait_time {
                sleep $wait_time
                last_modified = latest_file_modified_time $directory $file_type
            }
            if $systemd_notify {
                ^/usr/bin/systemd-notify $"--status='Uploading files in ($directory) to Immich'"
            }
            (^/usr/bin/podman run 
                --cgroups=no-conmon 
                --rm
                --sdnotify=conmon
                --replace
                --env IMMICH_INSTANCE_URL $immich_instance_url
                --name immich-cli
                --network podman
                --pull newer
                --secret immich_api_key,type=env,target=IMMICH_API_KEY
                --user (^id -u) + ":" + (^id -g)
                --userns keep-id
                --volume $"($directory):/import:z"
                $"ghcr.io/immich-app/immich-cli:($immich_cli_tag)"
                    upload
                    --delete
                    --recursive
                    /import
            )
            if $env.LAST_EXIT_CODE == 0 {
                log info $"Images in ($directory) uploaded"
            } else {
                log error $"Failed to upload images in ($directory). Podman command failed with exit code ($env.LAST_EXIT_CODE)"
            }
            if $systemd_notify {
                ^/usr/bin/systemd-notify $"--status='Watching for ($file_type) files in ($directory)'"
            }
        }
    }
}
