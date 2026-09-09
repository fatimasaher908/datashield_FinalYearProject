import 'dart:typed_data';
import 'package:flutter/material.dart';

import '../utils/app_colors.dart';
import 'gallery_screen.dart';

class DecryptedContentScreen extends StatelessWidget {
final String picturesFolderUri;
final Uint8List dek;

const DecryptedContentScreen({
super.key,
required this.picturesFolderUri,
required this.dek,
});

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: AppColors.background,
body: SafeArea(
child: Padding(
padding: const EdgeInsets.all(25),
child: Column(
children: [

          // ==================================================
          // HEADER
          // ==================================================

          Row(
            children: [
              IconButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                ),
              ),

              Image.asset(
                "assets/images/logo.JPG",
                width: 42,
                height: 42,
                fit: BoxFit.contain,
              ),

              const SizedBox(width: 10),

              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "DATASHIELD",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    Text(
                      "Secure Mobile Data & Management System",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 45),

          // ==================================================
          // TITLE
          // ==================================================

          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Protected Pictures",
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 8),

          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "View your encrypted pictures securely",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 15,
              ),
            ),
          ),

          const SizedBox(height: 30),

          // ==================================================
          // PICTURES FOLDER
          // ==================================================

          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GalleryScreen(
                    folderName: "Pictures",
                    folderUri: picturesFolderUri,
                    dek: dek,
                  ),
                ),
              );
            },

            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.cyan.withOpacity(.35),
                ),
              ),

              child: Row(
                children: [

                  // FOLDER ICON

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: AppColors.buttonGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),

                    child: const Icon(
                      Icons.photo_library,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),

                  const SizedBox(width: 18),

                  // TEXT

                  const Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [

                        Text(
                          "Pictures",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        SizedBox(height: 5),

                        Text(
                          "View encrypted photos and videos",
                          style: TextStyle(
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Icon(
                    Icons.arrow_forward_ios,
                    color: AppColors.cyan,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),

          const Text(
            "Your pictures are protected by DataShield.",
            style: TextStyle(
              color: Colors.white54,
            ),
          ),
        ],
      ),
    ),
  ),
);

}
}
