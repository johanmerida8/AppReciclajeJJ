  import 'package:flutter/material.dart';
  import '/screen/administrator/CreateCycleForm.dart';
  import '/model/admin/cycle_model.dart';

  class CreateCycleFormFullScreen extends StatelessWidget {
    final List<CycleModel> existingCycles;
    const CreateCycleFormFullScreen({super.key, required this.existingCycles});
    

    @override
    Widget build(BuildContext context) {
      return DraggableScrollableSheet(
        initialChildSize: 1,
        maxChildSize: 1,
        minChildSize: 1,
        expand: true,
        builder: (context, scrollController) {
          return Material(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Column(
              children: [
                AppBar(
                  automaticallyImplyLeading: false,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  backgroundColor: Colors.white,
                  elevation: 0.6,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  title: const Text("Crear nuevo Ciclo"),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: CreateCycleForm(
                      existingCycles: existingCycles,  // ⚡ pasamos a form
                    ),
                  ),
                )
              ],
            ),
          );
        },
      );
    }
  }
