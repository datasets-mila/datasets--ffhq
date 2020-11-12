#!/bin/bash

function exit_on_error_code {
	ERR=$?
	if [[ ${ERR} -ne 0 ]]
	then
		>&2 echo "$(tput setaf 1)ERROR$(tput sgr0): $1: ${ERR}"
		exit ${ERR}
	fi
}

function test_enhanced_getopt {
	! getopt --test > /dev/null
	if [[ ${PIPESTATUS[0]} -ne 4 ]]
	then
		>&2 echo "enhanced getopt is not available in this environment"
		exit 1
	fi
}

function enhanced_getopt {
	NAME=$0
	while [[ $# -gt 0 ]]
	do
		arg=$1; shift
		case ${arg} in
			--options) OPTIONS="$1"; shift ;;
			--longoptions) LONGOPTIONS="$1"; shift ;;
			--name) NAME="$1"; shift ;;
			--) break ;;
			-h | --help | *)
			if [[ "${arg}" != "-h" ]] && [[ "${arg}" != "--help" ]]
			then
				>&2 echo "Unknown option [${arg}]"
			fi
			>&2 echo "Options for $(basename "$0") are:"
			>&2 echo "--options OPTIONS The short (one-character) options to be recognized"
			>&2 echo "--longoptions LONGOPTIONS The long (multi-character) options to be recognized"
			>&2 echo "--name NAME name that will be used by the getopt routines when it reports errors"
			exit 1
			;;
		esac
	done

	PARSED=`getopt --options="${OPTIONS}" --longoptions="${LONGOPTIONS}" --name="${NAME}" -- "$@"`
	if [[ ${PIPESTATUS[0]} -ne 0 ]]
	then
		exit 2
	fi

	echo "${PARSED}"
}

function jug_exec {
	JUG_ARGV=()
	while [[ $# -gt 0 ]]
	do
		arg=$1; shift
		case ${arg} in
			--) break ;;
			*) JUG_ARGV+=("${arg}") ;;
		esac
	done
	# Remove trailing '/' in argv before sending to jug
	scripts/jug_exec.py "${JUG_ARGV[@]%/}" -- "${@%/}"
	jug sleep-until "${JUG_ARGV[@]%/}" scripts/jug_exec.py -- "${@%/}"
}

function init_conda_env {
	while [[ $# -gt 0 ]]
	do
		arg=$1; shift
		case ${arg} in
			--name) NAME="$1"; shift
			echo "name = [${NAME}]"
			;;
			--tmp) TMPDIR="$1"; shift
			echo "tmp = [${TMPDIR}]"
			;;
			-h | --help | *)
			if [[ "${arg}" != "-h" ]] && [[ "${arg}" != "--help" ]]
			then
				>&2 echo "Unknown option [${arg}]"
			fi
			>&2 echo "Options for $(basename "$0") are:"
			>&2 echo "--name NAME conda env prefix name"
			>&2 echo "--tmp DIR tmp dir to hold the conda prefix"
			exit 1
			;;
		esac
	done

	# Configure conda for bash shell
	eval "$(conda shell.bash hook)"

	if [[ ! -d "${TMPDIR}/env/${NAME}/" ]]
	then
		conda create --prefix "${TMPDIR}/env/${NAME}/" --yes --no-default-packages || \
		exit_on_error_code "Failed to create ${NAME} conda env"
	fi

	conda activate "${TMPDIR}/env/${NAME}/" && \
	exit_on_error_code "Failed to activate ${NAME} conda env"
}

function init_venv {
	while [[ $# -gt 0 ]]
	do
		arg=$1; shift
		case ${arg} in
			--name) NAME="$1"; shift
			echo "name = [${NAME}]"
			;;
			--tmp) TMPDIR="$1"; shift
			echo "tmp = [${TMPDIR}]"
			;;
			-h | --help | *)
			if [[ "${arg}" != "-h" ]] && [[ "${arg}" != "--help" ]]
			then
				>&2 echo "Unknown option [${arg}]"
			fi
			>&2 echo "Options for $(basename "$0") are:"
			>&2 echo "--name NAME venv prefix name"
			>&2 echo "--tmp DIR tmp dir to hold the virtualenv prefix"
			exit 1
			;;
		esac
	done

	if [[ -z "${NAME}" ]]
	then
		>&2 echo "--name NAME venv prefix name"
		>&2 echo "--tmp DIR tmp dir to hold the virtualenv prefix"
		>&2 echo "Missing --name and/or --tmp options"
		exit 1
	fi

	if [[ ! -d "${TMPDIR}/venv/${NAME}/" ]]
	then
		mkdir -p "${TMPDIR}/venv/${NAME}/" && \
		virtualenv --no-download "${TMPDIR}/venv/${NAME}/" || \
		exit_on_error_code "Failed to create ${NAME} venv"
	fi

	source "${TMPDIR}/venv/${NAME}/bin/activate" || \
	exit_on_error_code "Failed to activate ${NAME} venv"
	python -m pip install --no-index --upgrade pip
}

function print_annex_checksum {
	while [[ $# -gt 0 ]]
	do
		arg="$1"; shift
		case "${arg}" in
			-c | --checksum) CHECKSUM="$1"; shift ;;
			-h | --help)
			>&2 echo "Options for $(basename "$0") are:"
			>&2 echo "[-c | --checksum CHECKSUM] checksum to print"
			exit 1
			;;
			--) break ;;
			*) >&2 echo "Unknown argument [${arg}]"; exit 3 ;;
		esac
	done

	for file in "$@"
	do
		annex_file=`ls -l -- "${file}" | grep -o ".git/annex/objects/.*/${CHECKSUM}.*"`
		if [[ ! -f "${annex_file}" ]]
		then
			continue
		fi
		checksum=`echo "${annex_file%.*}" | xargs basename | grep -oEe"--.*"`
		echo "${checksum:2}  ${file}"
	done
}

function rclone_copy {
	while [[ $# -gt 0 ]]
	do
		arg="$1"; shift
		case "${arg}" in
			--remote) REMOTE="$1"; shift
			echo "remote = [${REMOTE}]"
			;;
			--root) GDRIVE_DIR_ID="$1"; shift
			echo "root = [${GDRIVE_DIR_ID}]"
			;;
			-h | --help)
			>&2 echo "Options for $(basename "$0") are:"
			>&2 echo "--root GDRIVE_DIR_ID Google Drive root directory id"
			exit 1
			;;
			--) break ;;
			*) >&2 echo "Unknown argument [${arg}]"; exit 3 ;;
		esac
	done

	for src_w_dest in "$@"
	do
		src_w_dest=(${src_w_dest[@]})
		src=${src_w_dest[0]}
		dest=${src_w_dest[1]}
		rclone copy --progress --create-empty-src-dirs --copy-links \
			--drive-root-folder-id=${GDRIVE_DIR_ID} ${REMOTE}:${src} ${dest}
	done
}

if [[ ! -z "$@" ]]
then
	"$@"
fi
