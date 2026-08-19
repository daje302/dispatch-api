export function notFound(req, res, next) {
  res.status(404).json({ error: 'Ruta no encontrada' });
}

export function errorHandler(err, req, res, next) {
  console.error('[error]', err);
  const status = err.statusCode || 500;
  const message =
    status >= 500 ? 'Error interno del servidor' : err.message;
  res.status(status).json({
    error: message,
    ...(req.app.get('env') === 'development' && status >= 500
      ? { detail: err.message }
      : {}),
  });
}

export class ApiError extends Error {
  constructor(statusCode, message) {
    super(message);
    this.statusCode = statusCode;
  }
}