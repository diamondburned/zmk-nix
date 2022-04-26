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

		export ZEPHYR_TOOLCHAIN_VARIANT=gnuarmemb
		# ./zmk/zephyr/cmake/toolchain/gnuarmemb/generic.cmake:19
		# ./zmk/zephyr/cmake/toolchain/gnuarmemb/generic.cmake:28
		export GNUARMEMB_TOOLCHAIN_PATH=/usr

		shields=(${lib.concatStringsSep " " config.build.shields})
		for shield in ''${shields[@]}; {
			west build -d build/$shield -b ${config.build.board} -- -DSHIELD=$shield
		}

		echo "Outputs:"
		printf -- "- ${root}/zmk/app/build/%s\n" "''${shields[@]}"
	'';

	initFile = pkgs.writeText "init.sh" ''
		virtualenv venv
		. venv/bin/activate

		[[ -d ${root}/zmk/modules/ ]] || (
			cd ${root}/zmk
			west init -l app/
			west update
			west zephyr-export
			pip3 install -r zephyr/scripts/requirements-base.txt
		)

		. ${keymaps}
		. ~/.bashrc
	'';

	fhs = pkgs.buildFHSUserEnv {
		name = "zmk-fhs-env";

		targetPkgs = pkgs: with pkgs; [
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
		];

		runScript = ''bash --init-file ${initFile}'';
	};

in fhs.env
