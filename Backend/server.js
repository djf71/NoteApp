const express = require('express');
const multer = require('multer');
const cors = require('cors');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = 3000;

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Create upload directory if it doesn't exist
const uploadDir = path.join(__dirname, 'uploads');
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir);
}

// Multer config: store images in /uploads
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, uploadDir);
  },
  filename: function (req, file, cb) {
    const timestamp = Date.now();
    const filename = `${timestamp}-${file.originalname}`;
    cb(null, filename);
  },
});

const upload = multer({ storage });

// Upload endpoint
app.post('/upload', upload.single('image'), (req, res) => {
  const image = req.file;
  const text = req.body.text;

  if (!image || !text) {
    return res.status(400).send('Missing image or text');
  }

  console.log(`Received: ${image.filename}, Label: "${text}"`);

  // Optional: Save text label as a JSON file
  const metadata = {
    filename: image.filename,
    text,
    uploadedAt: new Date().toISOString(),
  };

  fs.writeFileSync(
    path.join(uploadDir, `${image.filename}.json`),
    JSON.stringify(metadata, null, 2)
  );

  res.status(200).send('Upload successful');
});

// Start server
app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});
