import 'package:flutter/material.dart';
import '../models/note.dart';
import '../services/document_service.dart';

class DocumentListWidget extends StatelessWidget {
  final List<DocumentItem> documents;
  final Function(int index) onDelete;
  final Function(int index)? onTransfer;
  final Color? accentColor;

  const DocumentListWidget({
    super.key,
    required this.documents,
    required this.onDelete,
    this.onTransfer,
    this.accentColor,
  });

  Color _getExtensionColor(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return Colors.red.shade700;
      case 'xlsx':
      case 'xls':
      case 'csv':
        return Colors.green.shade700;
      case 'docx':
      case 'doc':
        return Colors.blue.shade700;
      case 'txt':
      case 'rtf':
        return Colors.blueGrey;
      case 'pptx':
      case 'ppt':
        return Colors.deepOrange;
      default:
        return Colors.purple.shade700;
    }
  }

  IconData _getExtensionIcon(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'xlsx':
      case 'xls':
      case 'csv':
        return Icons.table_chart_rounded;
      case 'docx':
      case 'doc':
        return Icons.description_rounded;
      case 'txt':
      case 'rtf':
        return Icons.text_snippet_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (documents.isEmpty) return const SizedBox.shrink();

    final color = accentColor ?? Colors.deepPurple;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.attach_file_rounded, size: 18, color: color),
            const SizedBox(width: 6),
            Text(
              'Ekli Belgeler & Dosyalar (${documents.length})',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: documents.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final doc = documents[index];
            final extColor = _getExtensionColor(doc.extension);
            final extIcon = _getExtensionIcon(doc.extension);

            return InkWell(
              onTap: () async {
                final err = await DocumentService.openDocument(doc);
                if (err != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Dosya açılamadı: $err')),
                  );
                }
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: extColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: extColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    // Dosya Türü Rozeti
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: extColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(extIcon, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 12),

                    // Dosya Adı ve Boyutu
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            doc.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: extColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  doc.extension.toUpperCase(),
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: extColor),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                doc.formattedSize,
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Menü (⋮)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                      onSelected: (val) async {
                        if (val == 'open') {
                          final err = await DocumentService.openDocument(doc);
                          if (err != null && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Dosya açılamadı: $err')),
                            );
                          }
                        } else if (val == 'transfer') {
                          onTransfer?.call(index);
                        } else if (val == 'delete') {
                          onDelete(index);
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'open',
                          child: Row(
                            children: [
                              Icon(Icons.open_in_new_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('Aç'),
                            ],
                          ),
                        ),
                        if (onTransfer != null)
                          const PopupMenuItem(
                            value: 'transfer',
                            child: Row(
                              children: [
                                Icon(Icons.drive_file_move_outlined, size: 18),
                                SizedBox(width: 8),
                                Text('Başka Nota Kopyala / Taşı'),
                              ],
                            ),
                          ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                              SizedBox(width: 8),
                              Text('Sil', style: TextStyle(color: Colors.redAccent)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
