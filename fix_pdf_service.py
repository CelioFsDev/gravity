import os

file_path = r'd:\REPOSITORIO GIT\gravity\lib\core\services\catalog_pdf_service.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Line 273 (1-indexed) is lines[272]
# Line 310 (1-indexed) is lines[309]
start_idx = 272 
end_idx = 309

new_content = """              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Builds the variant thumb layout based on quantity rules
  static pw.Widget _buildVariantThumbsLayout(
      List<MapEntry<String, String>> variants) {
    final count = variants.length;
    if (count == 4) {
      // Case 4: Column (vertical)
      return pw.Column(
        children: variants
            .map((e) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 6),
                  child: _buildSwatchThumb(e.key, e.value, small: true),
                ))
            .toList(),
      );
    } else if (count == 3) {
      // Case 3: 2+1 layout
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              _buildSwatchThumb(variants[0].key, variants[0].value),
              pw.SizedBox(width: 8),
              _buildSwatchThumb(variants[1].key, variants[1].value),
            ],
          ),
          pw.SizedBox(height: 6),
          _buildSwatchThumb(variants[2].key, variants[2].value),
        ],
      );
    } else {
      // Case 1 & 2: 1-2 horizontal
      return pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: variants.asMap().entries.map((entry) {
          return pw.Padding(
            padding: pw.EdgeInsets.only(left: entry.key == 0 ? 0 : 8),
            child: _buildSwatchThumb(entry.value.key, entry.value.value),
          );
        }).toList(),
      );
    }
  }

  /// Helper for a single variant swatch thumb
  static pw.Widget _buildSwatchThumb(String label, String path,
      {bool small = false}) {
    final thumbWidth = small ? 42.0 : 56.0;
    final thumbHeight = thumbWidth * 1.3;
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(
          width: thumbWidth,
          height: thumbHeight,
          decoration: pw.BoxDecoration(
            borderRadius: pw.BorderRadius.circular(10),
            border: pw.Border.all(color: PdfColors.grey200, width: 0.5),
          ),
          child: pw.ClipRRect(
            horizontalRadius: 10,
            verticalRadius: 10,
            child: _buildImageBox(
              path,
              height: thumbHeight,
              width: thumbWidth,
              radius: 10,
            ),
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Container(
          width: thumbWidth + 10,
          child: pw.Text(
            label.toUpperCase(),
            style: pw.TextStyle(
              fontSize: small ? 7 : 8,
              letterSpacing: 0.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
            ),
            textAlign: pw.TextAlign.center,
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
          ),
        ),
      ],
    );
  }
"""

lines[start_idx:end_idx+1] = [new_content]

with open(file_path, 'w', encoding='utf-8') as f:
    f.writelines(lines)

print("File updated successfully.")
