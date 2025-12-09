import joi, { string } from "joi";

export const PostValidator = joi.object({
  name: joi.string().required().min(3).max(100),
  description: joi.string().required().min(10),
  price: joi.number().min(1).required(),
  stock: joi.number().min(0).required(),
  category: joi.string(),
});
