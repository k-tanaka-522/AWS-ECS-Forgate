/**
 * Users Routes
 */

import { Router } from 'express';
import { UsersController } from '../controllers/users.controller';

export const usersRouter = Router();
const controller = new UsersController();

// User registration and login
usersRouter.post('/register', controller.register.bind(controller));
usersRouter.post('/login', controller.login.bind(controller));
