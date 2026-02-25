#!/bin/bash
#
# Copyright 2026 Niladri Das (bniladridas). All rights reserved.
# This source code is proprietary. Unauthorized use, modification, or
# distribution is strictly prohibited. See LICENSE for full terms.

# Add SPDX header to generated .mocks.dart files

HEADER="// Copyright 2026 Niladri Das (bniladridas). All rights reserved.
// This source code is proprietary. Unauthorized use, modification, or
// distribution is strictly prohibited. See LICENSE for full terms.

"

for file in test/*.mocks.dart; do
  if [ -f "$file" ]; then
    # Check if header is already present
    if ! head -5 "$file" | grep -q "SPDX-License-Identifier"; then
      # Create temp file with header + original content
      {
        echo "$HEADER"
        cat "$file"
      } > "${file}.tmp"
      mv "${file}.tmp" "$file"
      echo "Added header to $file"
    fi
  fi
done
