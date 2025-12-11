# DOCX Template Setup

This folder should contain `document_template.docx` for generating Word documents from scanned images.

## Quick Setup (Recommended)

### Option 1: Use the Python Script
```bash
cd scripts
pip install python-docx
python create_docx_template.py
```

### Option 2: Create Manually in Microsoft Word

1. Open Microsoft Word
2. Create a new blank document
3. Set narrow margins (0.5" on all sides)
4. Type the following text exactly as shown:

```
{% for page in pages %}
{{%img}}
{% endfor %}
```

5. Save the file as `document_template.docx` in this folder (`assets/docx/`)

## How It Works

The `docx_template` package uses Jinja2-like syntax:
- `{% for page in pages %}` - Loops through each scanned page
- `{{%img}}` - Inserts the image for that page
- `{% endfor %}` - Ends the loop

Each scanned page will be inserted as a full-width image in the Word document.

## Troubleshooting

If DOCX export fails:
1. Verify `document_template.docx` exists in `assets/docx/`
2. Check that the template contains the correct tags
3. Ensure the file is a valid .docx file (not corrupted)

## Alternative: Simple Template

If the above doesn't work, create a completely blank Word document and save it as `document_template.docx`. The app will handle image insertion programmatically.
