const express = require('express');
const router = express.Router();

// Health check endpoint
router.get('/check', (req, res) => {
  console.log('[Health] Health check requested');
  res.status(200).json({
    status: 'success',
    message: 'CERS Backend API is running',
    timestamp: new Date().toISOString(),
    version: '1.0.0',
  });
});

module.exports = router;