const errorHandler = (err, req, res, next) => {
  console.error(err.stack);

  if (err.name === 'ValidationError') {
    const errors = Object.values(err.errors).map(error => error.message);
    return res.status(400).json({ message: 'Validation Error', errors });
  }

  if (err.code === 11000) {
    return res.status(400).json({ message: 'Duplicate transaction' });
  }

  res.status(err.status || 500).json({
    message: err.message || 'Internal Server Error'
  });
};

module.exports = { errorHandler };