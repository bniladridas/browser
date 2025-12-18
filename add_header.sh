#!/bin/bash
# SPDX-License-Identifier: MIT
#
# Copyright 2025 bniladridas. All rights reserved.
# Use of this source code is governed by a MIT license that can be
# found in the LICENSE file.

# Add SPDX header to generated .mocks.dart files

HEADER="// SPDX-License-Identifier: MIT
//
// Copyright 2025 bniladridas. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

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