#!/bin/sh

NEWROOT="${NEWROOT:-/sysroot}"

[ -f "${NEWROOT}/etc/arch-rebase-fix.stamp" ] && exit 0
[ -f "${NEWROOT}/etc/passwd" ] || exit 0

# ============================================================
# 1. Remove system GROUPS defined in sysusers.d
# ============================================================

GROUPS_TO_REMOVE=$(grep -h "^g " "${NEWROOT}"/usr/lib/sysusers.d/*.conf 2>/dev/null | \
    sed -e 's/^g  *//' -e 's/  *.*//' | \
    grep -v -e "wheel" -e "root" -e "sudo" | \
    tr '\n' '|' | sed 's/||*/|/g; s/|$//; s/^|//')

if [ -n "${GROUPS_TO_REMOVE}" ]; then
    for target_file in "${NEWROOT}/etc/group" "${NEWROOT}/etc/gshadow"; do
        [ -f "$target_file" ] || continue
        sed -E "/^(${GROUPS_TO_REMOVE}):/d" "${target_file}" > "${target_file}.tmp"
        mv "${target_file}.tmp" "${target_file}"
    done
fi

# ============================================================
# 2. Remove system USERS defined in sysusers.d
# ============================================================

USERS_TO_REMOVE=$(grep -h "^u " "${NEWROOT}"/usr/lib/sysusers.d/*.conf 2>/dev/null | \
    sed -e 's/^u  *//' -e 's/  *.*//' | \
    grep -v -e "root" | \
    tr '\n' '|' | sed 's/||*/|/g; s/|$//; s/^|//')

if [ -n "${USERS_TO_REMOVE}" ]; then
    for target_file in "${NEWROOT}/etc/passwd" "${NEWROOT}/etc/shadow"; do
        [ -f "$target_file" ] || continue
        sed -E "/^(${USERS_TO_REMOVE}):/d" "${target_file}" > "${target_file}.tmp"
        mv "${target_file}.tmp" "${target_file}"
    done
fi

# ============================================================
# 3. Clean /etc/subuid and /etc/subgid of non-existent users
# ============================================================

for subfile in "${NEWROOT}/etc/subuid" "${NEWROOT}/etc/subgid"; do
    [ -f "$subfile" ] || continue
    # Build list of valid users
    while IFS=: read -r subuser rest; do
        grep -q "^${subuser}:" "${NEWROOT}/etc/passwd" || \
            sed -i "/^${subuser}:/d" "$subfile"
    done < "$subfile"
done

# ============================================================
# 4. Fix permissions
# ============================================================

chmod 0644 "${NEWROOT}/etc/passwd"
chmod 0644 "${NEWROOT}/etc/group"
chmod 0000 "${NEWROOT}/etc/shadow"
chmod 0000 "${NEWROOT}/etc/gshadow"

touch "${NEWROOT}/etc/arch-rebase-fix.stamp"
sync
