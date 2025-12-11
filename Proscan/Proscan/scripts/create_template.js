/**
 * Simple script to create a DOCX template for the scanner app.
 * 
 * Requirements:
 *   npm install docx
 * 
 * Usage:
 *   node scripts/create_template.js
 */

const fs = require('fs');
const path = require('path');
const { Document, Packer, Paragraph, TextRun } = require('docx');

async function createTemplate() {
  // Create a simple document with template tags
  const doc = new Document({
    sections: [{
      properties: {
        page: {
          margin: {
            top: 720,    // 0.5 inch
            right: 720,
            bottom: 720,
            left: 720,
          },
        },
      },
      children: [
        new Paragraph({
          children: [
            new TextRun({
              text: '{% for page in pages %}',
              size: 2, // Very small
            }),
          ],
        }),
        new Paragraph({
          children: [
            new TextRun({
              text: '{{%img}}',
              size: 2,
            }),
          ],
        }),
        new Paragraph({
          children: [
            new TextRun({
              text: '{% endfor %}',
              size: 2,
            }),
          ],
        }),
      ],
    }],
  });

  // Generate and save
  const buffer = await Packer.toBuffer(doc);
  const outputPath = path.join(__dirname, '..', 'assets', 'docx', 'document_template.docx');
  
  fs.writeFileSync(outputPath, buffer);
  console.log('✓ Template created successfully at:', outputPath);
  console.log('  The Flutter app can now generate DOCX files from scanned images.');
}

createTemplate().catch(err => {
  console.error('Error creating template:', err);
  console.log('\nMake sure you have installed the required package:');
  console.log('  npm install docx');
  process.exit(1);
});
