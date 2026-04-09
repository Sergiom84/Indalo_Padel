/**
 * Middleware genérico de validación con Zod.
 * Valida body, query o params según el schema proporcionado.
 *
 * Uso: router.post('/', validate(mySchema), handler)
 *      router.get('/', validate(mySchema, 'query'), handler)
 */
const validate = (schema, source = 'body') => {
  return (req, res, next) => {
    const result = schema.safeParse(req[source]);

    if (!result.success) {
      const errors = result.error.issues.map((issue) => ({
        campo: issue.path.join('.'),
        mensaje: issue.message,
      }));

      return res.status(400).json({
        error: 'Datos de entrada inválidos',
        detalles: errors,
      });
    }

    req[source] = result.data;
    next();
  };
};

export default validate;
export { validate };
