# 📄 PdfToolkit

An all-in-one PDF utility app built with Flutter — view, compress, scan documents into PDFs, and reorganize pages, all from your phone.

## 🚀 Features

✅ View and browse PDF documents

✅ Compress PDFs to reduce file size

✅ Scan physical documents straight into a PDF (ML Kit document scanner)

✅ Reorder and organize pages

✅ Pick and import existing PDFs/images

✅ Share PDFs to other apps

✅ Color-coded annotation support

## 🛠️ Tech Stack

- **Framework:** Flutter (Dart)
- **State Management:** Riverpod, GetX
- **PDF Engine:** Syncfusion Flutter PDF, pdfx
- **Document Scanning:** Google ML Kit Document Scanner
- **Storage:** Hive, Path Provider, Shared Preferences

## 📦 Getting Started

```
git clone https://github.com/soomro09/PdfToolkit.git
cd PdfToolkit
flutter pub get
flutter run
```

## 📁 Project Structure

```
lib/
├── core/       # App-wide config & utilities
├── feature/    # Feature modules (home, pdf, pdf_compress, splash)
├── models/     # Data models
├── services/   # Business logic & platform services
├── viewmodels/ # State/view logic
├── views/      # UI screens
└── main.dart
```
