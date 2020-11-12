#!/bin/bash
set -o errexit -o pipefail -o noclobber

# this script is meant to be used with 'datalad run'

source scripts/utils.sh echo -n

function delete_remote {
	echo "Deleting ${REMOTE} access token"
	rclone config delete ${REMOTE}
}

test_enhanced_getopt

PARSED=$(enhanced_getopt --options "d,h" --longoptions "directory:,client-id:,secret:,help" --name "$0" -- "$@")
eval set -- "${PARSED}"

GDRIVE_DIR_ID=$(git config --file scripts/ffhq_config --get google.directory)
CLIENT_ID=$(git config --file scripts/ffhq_config --get google.client-id)
CLIENT_SECRET=$(git config --file scripts/ffhq_config --get google.client-secret)
REMOTE=__gdrive

while [[ $# -gt 0 ]]
do
	arg="$1"; shift
	case "${arg}" in
		-d | --directory) GDRIVE_DIR_ID="$1"; shift
		echo "directory = [${GDRIVE_DIR_ID}]"
		;;
		--client-id) CLIENT_ID="$1"; shift
		echo "client-id = [${CLIENT_ID}]"
		;;
		--secret) CLIENT_SECRET="$1"; shift
		echo "secret = [${CLIENT_SECRET}]"
		;;
		-h | --help)
		>&2 echo "Options for $(basename "$0") are:"
		>&2 echo "[-d | --directory GDRIVE_DIR_ID] Google Drive root directory id (optional)"
		>&2 echo "[--client-id CLIENT_ID] Google application client id (optional)"
		>&2 echo "[--secret CLIENT_SECRET] OAuth Client Secret (optional)"
		exit 1
		;;
		--) break ;;
		*) >&2 echo "Unknown argument [${arg}]"; exit 3 ;;
	esac
done

init_conda_env --name rclone --tmp tmp
conda install --yes --strict-channel-priority --use-local -c defaults -c conda-forge rclone=1.51.0

trap delete_remote EXIT

if [[ -z "$(rclone listremotes | grep -o "^${REMOTE}:")" ]]
then
	rclone config create ${REMOTE} drive client_id ${CLIENT_ID} \
		client_secret ${CLIENT_SECRET} \
		scope "drive" \
		root_folder_id ${GDRIVE_DIR_ID} \
		config_is_local false \
		config_refresh_token false
fi

rclone_copy --remote ${REMOTE} --root ${GDRIVE_DIR_ID} -- "zips/ ./" \
	"ffhq-dataset-v2.json ./"

print_annex_checksum -c MD5 -- *.zip ffhq-dataset-v2.json > md5sums
