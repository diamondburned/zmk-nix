{ pkgs ? import <nixpkgs> {} }:

# https://sourcegraph.com/github.com/qmk/qmk_firmware/-/blob/shell.nix
# https://github.com/nickcoutsos/keymap-editor

let config = import ./config.nix { inherit pkgs; };

	lib  = pkgs.lib;
	root = builtins.toString ./.; # absolute path within system

	keymaps = pkgs.writeScript "keymaps.sh" (
		lib.mapAttrsToList
			(dst: src: "cp ${src} ./zmk/app/boards/${dst}/")
			(config.keymaps)
	);

	build-zmk = pkgs.writeShellScriptBin "build-zmk" ''
		set -e
		rm $(find ${root} -name CMakeCache.txt)
		cd ${root}/zmk/app

		shields=(${lib.concatStringsSep " " config.build.shields})
		for shield in ''${shields[@]}; {
			west build -d build/$shield -b ${config.build.board} -- -DSHIELD=$shield
		}

		echo "Outputs:"
		printf -- "- ${root}/zmk/app/build/%s\n" "''${shields[@]}"
	'';

	flash-zmk = pkgs.writeShellScriptBin "flash-zmk" ''
		set -e
		cd ${root}/zmk/app

		case "$1" in
		"west")
			flash() {
				[[ -e /dev/ttyACM0 ]] || {
					echo "/dev/ttyACM0 not found. Make sure to put your device in DFU mode."
					exit 1
				}
	
				sudo west flash --skip-rebuild --build-dir "$1"
			}
			;;
		"nicenano")
			device_name=NICENANO
			[[ -e /dev/disk/by-label/NICENANO ]] || {
				echo "The nice!nano is not yet plugged in."
				exit 1
			}

			device_path=$(cd /dev/disk/by-label; realpath $(readlink $device_name))
			regex_match="^''${device_path//\//\\/} on \(.*\) type .*"

			flash() {
				mount | grep "$regex_match" &> /dev/null || {
					udisksctl mount -b $device_path
				}

				mountpoint=$(mount | sed -n "s/$regex_match/\1/p")
				[[ ! $mountpoint ]] && {
					echo "Failed to mount NICENANO: mountpoint not found."
					exit 1
				}

				cp $1/zephyr/zmk.uf2 "$mountpoint/CURRENT.UF2"

				echo "Flashed nice!nano."
				udisksctl unmount -b $device_path &> /dev/null    \
					&& echo "Device is now safe to be unplugged." \
					|| echo "Device not gracefully unmounted. It may have restarted."
			}
			;;
		*)
			echo "usage: "
			echo "  flash-zmk nicenano - for a nice!nano device"
			echo "  flash-zmk west     - for any other device using 'west flash'"
			exit
		esac

		for build in ${root}/zmk/app/build/*; {
			read -p "Flashing $(basename $build). Insert device and hit Enter, or type 'skip'." ans

			case "$ans" in
			"skip")
				continue
				;;
			"")
				flash "$build"
				;;
			*)
				echo "Unknown gibberish given. Cancelling."
				exit 1
			esac
		}
	'';

	initFile = pkgs.writeText "init.sh" ''
		# virtualenv venv

		python -m venv venv
		. venv/bin/activate

		[[ -d ${root}/zmk/modules/ ]] || (
			cd ${root}/zmk
			west init -l app/
			west update
			west zephyr-export
			pip3 install -r zephyr/scripts/requirements-base.txt
		)

		export ZEPHYR_TOOLCHAIN_VARIANT=gnuarmemb
		export GNUARMEMB_TOOLCHAIN_PATH=${pkgs.gcc-arm-embedded-10}

		cleanup() {
			[[ -d ~/.cmake ]] && {
				command rm -rf /home/diamond/.cmake/packages/Zephyr*
				command find ~/.cmake -type d -empty -delete
			}
		}

		trap cleanup EXIT

		. ${keymaps}
		. ~/.bashrc
	'';

in pkgs.mkShell {
	name = "zmk-shell";

	buildInputs = with pkgs; [
		python38
		python38Packages.pip
		python38Packages.virtualenv
		python38Packages.west

		clang-tools
		coreutils
		cmake
		ninja
		dfu-programmer
		dfu-util
		gcc-arm-embedded-10
		git

		build-zmk
		flash-zmk
	];

	shellHook = builtins.readFile initFile;
}
