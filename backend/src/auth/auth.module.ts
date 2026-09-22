import { Global, Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { AuthService } from './auth.service';
import { AuthController, AccountController } from './auth.controller';
import { FirebaseService } from './firebase.service';
import { JwtAuthGuard } from './jwt-auth.guard';

@Global()
@Module({
  imports: [JwtModule.register({})],
  providers: [AuthService, FirebaseService, JwtAuthGuard],
  controllers: [AuthController, AccountController],
  exports: [FirebaseService, JwtAuthGuard, JwtModule],
})
export class AuthModule {}
