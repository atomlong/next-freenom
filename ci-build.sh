#!/bin/bash

# Add custom repositories to pacman
add_custom_repos()
{
[ -n "${CUSTOM_REPOS}" ] || { echo "You must set CUSTOM_REPOS firstly."; return 1; }
local repos=(${CUSTOM_REPOS//,/ })
local repo name
for repo in ${repos[@]}; do
name=$(sed -n -r 's/\[(\w+)\].*/\1/p' <<< ${repo})
[ -n "${name}" ] || continue
[ -z $(sed -rn "/^\[${name}]\s*$/p" /etc/pacman.conf) ] || continue
cp -vf /etc/pacman.conf{,.orig}
sed -r 's/]/&\nServer = /' <<< ${repo} >> /etc/pacman.conf
sed -i -r 's/^(SigLevel\s*=\s*).*/\1Never/' /etc/pacman.conf
pacman --sync --refresh --needed --noconfirm --disable-download-timeout ${name}-keyring && name="" || name="SigLevel = Never\n"
mv -vf /etc/pacman.conf{.orig,}
sed -r "s/]/&\n${name}Server = /" <<< ${repo} >> /etc/pacman.conf
done
}

# Run from here
cd ${CI_BUILD_DIR}
[ -z "${FREENOM_USERNAME}" ] && { echo "Environment variable 'FREENOM_USERNAME' is required."; exit 1; }
[ -z "${FREENOM_PASSWORD}" ] && { echo "Environment variable 'FREENOM_PASSWORD' is required."; exit 1; }
[ -z "${MAIL_USERNAME}" ] && { echo "Environment variable 'MAIL_USERNAME' is required."; exit 1; }
[ -z "${MAIL_PASSWORD}" ] && { echo "Environment variable 'MAIL_PASSWORD' is required."; exit 1; }
[ -z "${MAIL_TO}" ] && { echo "Environment variable 'MAIL_TO' is required."; exit 1; }
[ -z "${CUSTOM_REPOS}" ] && { echo "Environment variable 'CUSTOM_REPOS' is required."; exit 1; }
CUSTOM_REPOS=$(sed -e 's/$arch\b/\\$arch/g' -e 's/$repo\b/\\$repo/g' <<< ${CUSTOM_REPOS})
[[ ${CUSTOM_REPOS} =~ '$' ]] && eval export CUSTOM_REPOS=${CUSTOM_REPOS}
add_custom_repos

for ((i=0; i<5; i++)); do
pacman -S --needed --noconfirm --disable-download-timeout \
	freenom-git \
	docker-systemctl-replacement-git && break
done || { echo "Failed to install packages"; exit 1; }

CFG_PATH=$(pacman -Ql freenom-git | grep -Po '\S+/freenom\.conf$')

sed -i -r -e "s/^#?(FREENOM_USERNAME=(\"|')?)[^\"']*(.*)/\1${FREENOM_USERNAME}\3/" \
 -e "s/^#?(FREENOM_PASSWORD=(\"|')?)[^\"']*(.*)/\1${FREENOM_PASSWORD}\3/" \
 -e "s/^#?(MAIL_USERNAME=(\"|')?)[^\"']*(.*)/\1${MAIL_USERNAME}\3/" \
 -e "s/^#?(MAIL_PASSWORD=(\"|')?)[^\"']*(.*)/\1${MAIL_PASSWORD}\3/" \
 -e "s/^#?(TO=(\"|')?)[^\"']*(.*)/\1${MAIL_TO}\3/" \
 ${CFG_PATH}

systemctl.py start freenom.service

