#!/usr/bin/env nu
use std log

def directory_has_files [
    directory: path
    file_type: string = image  # Only check files which have this mime type
] {
    ls --all --mime-type $"($directory)" | where type starts-with $file_type | is-not-empty
}

# Get the modification time of the most recently modified file in the given directory.
def latest_file_modified_time [
    directory: path
    file_type: string = image  # Only check files which have this mime type
] {
    ls --all --mime-type $"($directory)" | where type starts-with $file_type | sort-by --reverse modified | first | get modified
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
            --pull newer
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
            --volume $"($target):/($filename):Z"
            $"ghcr.io/immich-app/immich-cli:($immich_cli_tag)"
                upload
                --delete
                $"/($filename)"
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
    directory # The directory to watch
    --file-glob = "**/*.jpg" # A glob pattern for the file extensions to watch
    --file-type = "image" # The mime type of the files to watch
    --immich-cli-tag = "latest" # The tag of the Immich CLI container image
    --immich-instance-url = "https://immich.jwillikers.io/api" # The URL of the Immich instance
    --systemd-notify # Enable systemd-notify support for running as a systemd service
    --wait-time = 3min  # The amount of time to wait after the last file has appeared before uploading
] {
    if $systemd_notify {
        ^/usr/bin/systemd-notify --ready
    }
    if (directory_has_files $directory $file_type) {
        if $systemd_notify {
            ^/usr/bin/systemd-notify $"--status=Uploading existing files in ($directory) to Immich"
        }
        log info $"Uploading existing files in ($directory) to Immich"
        upload $directory --immich-cli-tag $immich_cli_tag --immich-instance-url $immich_instance_url
    }
    if $systemd_notify {
        ^/usr/bin/systemd-notify $"--status=Watching for ($file_type) files in ($directory)"
    }
    watch --glob $file_glob $directory { |op, path, new_path| 
        if $op == "Create" {
            log info $"File ($path) created"
            mut last_modified = (latest_file_modified_time $directory $file_type)
            while (date now) - $last_modified <= $wait_time {
                if $systemd_notify {
                    ^/usr/bin/systemd-notify $"--status=Waiting to upload image until ($wait_time) after the most recent file modification: ($last_modified)"
                }
                sleep $wait_time
                $last_modified = (latest_file_modified_time $directory $file_type)
            }
            if $systemd_notify {
                ^/usr/bin/systemd-notify $"--status=Uploading ($path) to Immich"
            }
            upload $path --immich-cli-tag $immich_cli_tag --immich-instance-url $immich_instance_url
            if $systemd_notify {
                ^/usr/bin/systemd-notify $"--status=Watching for ($file_type) files in ($directory)"
            }
        }
    }
}
