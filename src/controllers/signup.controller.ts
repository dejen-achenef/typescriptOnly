import { Request, Response } from "express";
import prisma from "../prisma/client";
import bcrypt from "bcryptjs";
import {
  userLoginvalidator,
  userSignupvalidator,
} from "../validators/user.validator";

export const Register = async (req: Request, res: Response) => {
  const { value, error } = userSignupvalidator.validate(req.body);
  if (error) {
    return res.status(400).json({ errors: error.details });
  }
  const { email, username, password } = value;

  const emailExists = await prisma.user.findUnique({ where: { email } });
  const usernameExists = await prisma.user.findUnique({ where: { username } });

  if (emailExists || usernameExists) {
    return res.status(400).json({ message: "User already exists" });
  }

  const hashedPassword = await bcrypt.hash(password, 12);

  try {
    const user = await prisma.user.create({
      data: { email, username, password: hashedPassword },
      select: {
        id: true,
        email: true,
        username: true,
      },
    });

    return res.status(201).json({
      message: "User created successfully",
      success: true,
      user,
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: "Failed to register user" });
  }
};
