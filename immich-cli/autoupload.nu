#!/usr/bin/env nu
use std log

def directory_has_files [
    directory: path
    mime_types: list = [image/jpeg video/mp4]  # Only check files which have these mime types
] {
    ls --all --mime-type $"($directory)" | where type in $mime_types | is-not-empty
}

# Get the modification time of the most recently modified file in the given directory.
def latest_file_modified_time [
    directory: path
    mime_types: list = [image/jpeg video/mp4]  # Only check files which have these mime types
] {
    ls --all --mime-type $"($directory)" | where type in $mime_types | sort-by --reverse modified | first | get modified
}

# Upload an image or images in a directory to Immich.
def upload [
    target: path # The image to upload
    --immich-cli-tag = "latest" # The tag of the Immich CLI container image
    --immich-instance-url = "https://immich.jwillikers.io/api" # The URL of the Immich instance
] {
    if ($target | path type) == dir {
        (^/usr/bin/podman run 
            --env $"IMMICH_INSTANCE_URL=($immich_instance_url)"
            --name immich-cli
            --network podman
            --sdnotify ignore
            --replace
            --rm
            --secret "immich_api_key,type=env,target=IMMICH_API_KEY"
            --user ((^id -u) + ":" + (^id -g))
            --userns keep-id
            --volume $"($target):/import:Z"
            $"ghcr.io/immich-app/immich-cli:($immich_cli_tag)"
                upload
                --delete
                --recursive
                /import
        )
        if $env.LAST_EXIT_CODE == 0 {
            log info $"Images in ($target) uploaded"
        } else {
            log error $"Failed to upload images in ($target). Podman command failed with exit code ($env.LAST_EXIT_CODE)"
        }
    } else {
        let directory = ($target | path dirname)
        let filename = ($target | path basename)
        (^/usr/bin/podman run 
            --env $"IMMICH_INSTANCE_URL=($immich_instance_url)"
            --name immich-cli
            --network podman
            --sdnotify ignore
            --pull newer
            --replace
            --rm
            --secret "immich_api_key,type=env,target=IMMICH_API_KEY"
            --user ((^id -u) + ":" + (^id -g))
            --userns keep-id
            --volume $"($directory):/import:z"
            $"ghcr.io/immich-app/immich-cli:($immich_cli_tag)"
                upload
                --delete
                $"/import/($filename)"
        )
        if $env.LAST_EXIT_CODE == 0 {
            log info $"Image ($target) uploaded"
        } else {
            log error $"Failed to upload image ($target). Podman command failed with exit code ($env.LAST_EXIT_CODE)"
        }
    }
}

# Watch for new pictures in the given directory and upload them to Immich.
def main [
    directory: directory # The directory to watch
    --mime-types: list = ["image/jpeg" "video/mp4"] # The mime types of the files to watch
    --immich-cli-tag: string = "latest" # The tag of the Immich CLI container image
    --immich-instance-url: string = "https://immich.jwillikers.io/api" # The URL of the Immich instance
    --systemd-notify # Enable systemd-notify support for running as a systemd service
    --wait-time: duration = 3min  # The amount of time to wait after the last file has appeared before uploading
] {
    if $systemd_notify {
        ^/usr/bin/systemd-notify --ready
    }
    if (directory_has_files $directory $mime_types) {
        if $systemd_notify {
            ^/usr/bin/systemd-notify $"--status=Uploading existing files in ($directory) to Immich"
        }
        log info $"Found existing files in ($directory)"
        mut last_modified = (latest_file_modified_time $directory $mime_types)
        while (date now) - $last_modified <= $wait_time {
            if $systemd_notify {
                ^/usr/bin/systemd-notify $"--status=Waiting to upload images until ($wait_time) after the most recent file modification: ($last_modified)"
            }
            sleep $wait_time
            $last_modified = (latest_file_modified_time $directory $mime_types)
        }
        log info $"Uploading existing files in ($directory) to Immich"
        if $systemd_notify {
            ^/usr/bin/systemd-notify $"--status=Uploading files in ($directory) to Immich"
        }
        upload $directory --immich-cli-tag $immich_cli_tag --immich-instance-url $immich_instance_url
    }
    if $systemd_notify {
        ^/usr/bin/systemd-notify $"--status=Watching for ($mime_types) files in ($directory)"
    }
    # Avoid exiting.
    while true {
        watch $directory { |op, path, new_path| 
            if $op == "Create" {
                if ((ls --mime-type $path | get type | first) in $mime_types) {
                    log info $"File ($path) created"
                    mut last_modified = (latest_file_modified_time $directory $mime_types)
                    while (date now) - $last_modified <= $wait_time {
                        if $systemd_notify {
                            ^/usr/bin/systemd-notify $"--status=Waiting to upload image until ($wait_time) after the most recent file modification: ($last_modified)"
                        }
                        sleep $wait_time
                        $last_modified = (latest_file_modified_time $directory $mime_types)
                    }
                    if $systemd_notify {
                        ^/usr/bin/systemd-notify $"--status=Uploading ($path) to Immich"
                    }
                    upload $path --immich-cli-tag $immich_cli_tag --immich-instance-url $immich_instance_url
                    if $systemd_notify {
                        ^/usr/bin/systemd-notify $"--status=Watching for ($mime_types) files in ($directory)"
                    }
                }
            }
        }
    }
    exit -1
}
