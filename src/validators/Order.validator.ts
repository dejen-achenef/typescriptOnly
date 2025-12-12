import Joi from "joi";

const orderItemSchema = Joi.object({
  productId: Joi.string().uuid().required(),
  quantity: Joi.number().integer().min(1).required(),
});

export const OrderValidator = Joi.object({
  items: Joi.array().items(orderItemSchema).min(1).required(),
});


