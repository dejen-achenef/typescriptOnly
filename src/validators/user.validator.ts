import joi from "joi";

export const userSignupvalidator = joi.object({
  password: joi
    .string()
    .min(8)
    .required()
    .regex(/[A-Z]/, "Must include at least one uppercase letter (A-Z)")
    .regex(/[a-z]/, "Must include at least one lowercase letter (a-z)")
    .regex(/[0-9]/, "Must include at least one number (0-9)")
    .regex(
      /[^A-Za-z0-9]/,
      "Must include at least one special character (e.g., !@#$%^&*)"
    ),
  email: joi.string().email().required(),

  // Username schema
  username: joi
    .string()
    .required()
    .regex(
      /^[a-zA-Z0-9]+$/,
      "Username must be alphanumeric without spaces or special characters"
    ),
});
export const userLoginvalidator = joi
  .object({
    password: joi
      .string()
      .min(8)
      .required()
      .regex(/[A-Z]/, "Must include at least one uppercase letter (A-Z)")
      .regex(/[a-z]/, "Must include at least one lowercase letter (a-z)")
      .regex(/[0-9]/, "Must include at least one number (0-9)")
      .regex(
        /[^A-Za-z0-9]/,
        "Must include at least one special character (e.g., !@#$%^&*)"
      ),
    email: joi.string().email(),

    // Username schema
    username: joi
      .string()

      .regex(
        /^[a-zA-Z0-9]+$/,
        "Username must be alphanumeric without spaces or special characters"
      ),
  })
  .or("email", "username");
