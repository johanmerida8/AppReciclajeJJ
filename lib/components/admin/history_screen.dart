import 'package:flutter/material.dart';
import 'package:reciclaje_app/database/admin/ArticleHistory_db.dart';
import 'package:reciclaje_app/model/admin/article_history_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HistoryBottomSheet extends StatefulWidget {
  final int articleId;
  final String articleName;

  const HistoryBottomSheet({
    super.key,
    required this.articleId,
    required this.articleName,
  });

  @override
  State<HistoryBottomSheet> createState() => _HistoryBottomSheetState();
}

class _HistoryBottomSheetState extends State<HistoryBottomSheet> {
  final ArticleHistoryDB articleHistoryDB = ArticleHistoryDB();

  Future<String> _getUserName(int userId) async {
    try {
      final res = await Supabase.instance.client
          .from('users')
          .select('names')
          .eq('idUser', userId)
          .single();
      return res['names'] ?? 'Usuario';
    } catch (_) {
      return 'Usuario';
    }
  }

  Future<String> _getCompanyName(int companyId) async {
    try {
      final res = await Supabase.instance.client
          .from('company')
          .select('nameCompany')
          .eq('idCompany', companyId)
          .single();
      return res['nameCompany'] ?? 'Empresa';
    } catch (_) {
      return 'Empresa';
    }
  }

  Future<String> _buildHistoryText(ArticleHistoryModel h) async {
    final actorName = await _getUserName(h.actorId);
    String? targetName;
    if (h.targetID != null) {
      targetName = await _getCompanyName(h.targetID!);
    }

    switch (h.description) {
      case 'published':
        return "$actorName publicó el artículo";
      case 'request_sent':
        return targetName != null
            ? "$targetName envió una solicitud a $actorName"
            : "$actorName envió una solicitud";
      case 'request_accepted':
        return targetName != null
            ? "$actorName aceptó la solicitud de $targetName"
            : "$actorName aceptó una solicitud";
      case 'delivered':
        return targetName != null
            ? "$actorName entregó el artículo a $targetName"
            : "$actorName entregó el artículo";
      default:
        return "$actorName realizó una acción";
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: articleHistoryDB.getArticleHistory(widget.articleId),
      builder: (_, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 200,
            child: Center(
              child: CircularProgressIndicator(color: Colors.teal),
            ),
          );
        }

        final history = snapshot.data as List<ArticleHistoryModel>;

        return Container(
          padding: const EdgeInsets.all(20),
          height: MediaQuery.of(context).size.height * 0.65,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 45,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 25),
              Text(
                widget.articleName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D8A8A),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: FutureBuilder(
                  future: Future.wait(history.map(_buildHistoryText)),
                  builder: (_, snap2) {
                    if (!snap2.hasData) {
                      return const Center(
                          child: CircularProgressIndicator(color: Colors.teal));
                    }

                    final items = snap2.data as List<String>;

                    if (items.isEmpty) {
                      return const Center(
                        child: Text(
                          "No hay historial",
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        return ListTile(
                          leading: const Icon(Icons.history, color: Colors.teal),
                          title: Text(items[i]),
                          subtitle: Text(history[i].formattedDate),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
