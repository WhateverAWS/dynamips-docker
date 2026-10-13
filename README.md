# Dynamips Docker

A Docker image containing [Dynamips](https://github.com/GNS3/dynamips), its runtime dependencies, and the `nvram_export` utility. Use it as a hypervisor to manage emulated routers or run a standalone router with your own compatible Cisco IOS image.

You need a working Docker installation. IOS images are not included; supply an image you are authorized to use. The published image supports `linux/amd64` and `linux/arm64`. ARM64 uses Dynamips' interpreter without JIT acceleration, so IOS emulation is significantly slower than with JIT.

## Pull the image

```sh
docker pull ghcr.io/whateveraws/dynamips:latest
```

To pin a runtime image revision, use its version and revision tag, for example:

```sh
docker pull ghcr.io/whateveraws/dynamips:0.2.25-r1
```

Both `latest` and version tags such as `0.2.25-r1` let Docker automatically select the image for your host's architecture. Architecture-specific tags such as `0.2.25-r1-amd64` and `0.2.25-r1-arm64` are also available.

Choose a published tag from the [GHCR package](https://github.com/WhateverAWS/dynamips-docker/pkgs/container/dynamips) and use the same tag in the commands below.

## Run the hypervisor

The default command starts the Dynamips hypervisor on TCP port `7200` inside the container.

```sh
mkdir -p ios work

docker run -d \
  --name dynamips \
  -p 127.0.0.1:7200:7200 \
  --mount "type=bind,src=$(pwd)/ios,dst=/ios,readonly" \
  --mount "type=bind,src=$(pwd)/work,dst=/work" \
  --workdir /work \
  ghcr.io/whateveraws/dynamips:latest
```

Place your IOS images in `ios/`. Hypervisor commands must use their container paths, such as `/ios/router.image`. The `work/` directory stores files written to the hypervisor's working directory, including logs and router state files.

Connect from the host with a TCP client such as netcat:

```sh
nc 127.0.0.1 7200
```

Enter `hypervisor version` to query the running emulator. This port accepts the Dynamips hypervisor control protocol. Starting the service does not create or boot a router: a client must create router instances, select their IOS images, configure interfaces, and start them. See the [upstream hypervisor documentation](https://github.com/GNS3/dynamips/tree/master/doc) for commands.

Inspect the container and stop it with:

```sh
docker ps --filter name=dynamips
docker logs -f dynamips
docker stop dynamips
```

Both `docker stop dynamips` and `podman stop dynamips` send `SIGINT`, which tells the hypervisor to shut down its router instances and exit cleanly. Save any IOS configuration you want to keep with `copy running-config startup-config`, as shutdown does not save the running configuration automatically.

You can start the hypervisor again with `docker start dynamips`. Router instances are not restored automatically, so your client must recreate them after restarting. If you no longer need the container, stop it and remove it with `docker rm dynamips`. Files in the mounted host directories remain available for future use.

## Run a standalone router

Place a compatible Cisco 7200 IOS image at `ios/router.image`, then run:

```sh
mkdir -p ios work

docker run --rm -it \
  --name dynamips-router \
  --mount "type=bind,src=$(pwd)/ios,dst=/ios,readonly" \
  --mount "type=bind,src=$(pwd)/work,dst=/work" \
  --workdir /work \
  --entrypoint dynamips \
  ghcr.io/whateveraws/dynamips:latest \
  -P 7200 -r 256 /ios/router.image
```

The router console appears in your terminal. `-P 7200` selects the emulated platform and `-r 256` assigns 256 MB of RAM. Adjust the platform, RAM, and other hardware options to match your IOS image. The mounted working directory preserves generated state files; save IOS configuration with `copy running-config startup-config` when needed.

To stop the standalone router cleanly:

1. Save any IOS configuration you want to keep with `copy running-config startup-config`.
2. In the attached router console, press **Ctrl+]**, release the keys, then press **q** to quit Dynamips.

You can also stop the container from another terminal:

```sh
docker stop dynamips-router
```

However, standalone Dynamips with a terminal console forwards `SIGINT` to IOS as Ctrl+C instead of exiting. Both `docker stop` and `podman stop` therefore wait for the stop timeout (10 seconds by default), then forcibly terminate it with `SIGKILL`. Use **Ctrl+]**, then **q** instead.

Connecting its emulated interfaces to other devices requires Dynamips network input/output (NIO) configuration.

## Command-line tools

The image includes `dynamips` and `nvram_export` executables. The default `CMD` starts the hypervisor. To run another command, supply the executable after the image name or override the entrypoint as shown above.

Display Dynamips usage by running it without arguments:

```sh
docker run --rm ghcr.io/whateveraws/dynamips:latest dynamips
```

The usage command exits with a nonzero status because no IOS image was supplied.

To export a saved NVRAM file, stop the router first and substitute its actual filename for `router_nvram`:

```sh
docker run --rm \
  --mount "type=bind,src=$(pwd)/work,dst=/work" \
  --entrypoint nvram_export \
  ghcr.io/whateveraws/dynamips:latest \
  /work/router_nvram /work/startup-config /work/private-config
```

The arguments are the input NVRAM file, output startup configuration, and optional output private configuration. Output files appear in `work/`.

## Build locally

From a checkout of this repository:

```sh
docker build -t dynamips:local .
```

Replace `ghcr.io/whateveraws/dynamips:latest` with `dynamips:local` in any example above. Building requires access to the Debian package repositories and upstream Dynamips source.

## Troubleshooting

- **IOS image cannot be opened:** check that the file exists in `ios/`, is readable, and is referenced using its `/ios/...` container path.
- **Working files cannot be written:** ensure `work/` exists and is writable by the container process. On SELinux hosts, bind mounts may need appropriate labeling.
- **Router fails to boot:** confirm the IOS image is compatible with the selected platform and has enough RAM. Inspect terminal output, `docker logs`, and files in `work/`.
- **High CPU usage:** configure an idle-PC value appropriate to your IOS image; standalone Dynamips accepts `--idle-pc <value>`.

## License

This project is licensed under [GPLv2](LICENSE). See [upstream Dynamips](https://github.com/GNS3/dynamips) for emulator documentation and source.
