import 'package:flutter_test/flutter_test.dart';
import 'package:catalogozapatillas/models/zapatilla.dart';
import 'package:catalogozapatillas/models/user_model.dart';
import 'package:catalogozapatillas/services/cart_service.dart';

void main() {
  group('Zapatilla model', () {
    test('parses JSON from backend correctly', () {
      final json = {
        'id': '60oLPAOBUSxs7XySkGKG',
        'nombre': 'Nike Air Jordan 1 Retro',
        'marca': 'Nike',
        'precio': 185,
        'talla': '40, 41, 42',
        'stock': 10,
        'imagenUrl': 'https://storage.googleapis.com/test/imagen.webp',
        'modelo3dUrl': 'https://storage.googleapis.com/test/shoe.glb',
        'descripcion': 'Zapatilla clásica de baloncesto',
        'activo': true,
        'createdAt': '2026-10-18T20:14:00.000Z',
        'updatedAt': '2026-10-18T20:14:00.000Z',
      };

      final z = Zapatilla.fromJson(json);
      expect(z.id, '60oLPAOBUSxs7XySkGKG');
      expect(z.nombre, 'Nike Air Jordan 1 Retro');
      expect(z.precio, 185.0);
      expect(z.tieneModelo3d, isTrue);
      expect(z.tallasDisponibles, ['40', '41', '42']);
    });
  });

  group('UserModel & AuthResponse', () {
    test('detects admin and cliente roles', () {
      final auth = AuthResponse.fromJson({
        'message': 'Inicio de sesión exitoso',
        'user': {
          'id': '123',
          'nombre': 'Admin',
          'email': 'admin@zapatillas.com',
          'rol': 'admin',
        },
        'accessToken': 'jwt-token',
      });

      expect(auth.user.isAdmin, isTrue);
      expect(auth.accessToken, 'jwt-token');
    });
  });

  group('CartService', () {
    test('adds items, updates quantity and simulates order', () async {
      final cart = CartService();
      const shoe = Zapatilla(
        id: 'z1',
        nombre: 'Adidas Samba OG',
        marca: 'Adidas',
        precio: 110.0,
        talla: '41',
        stock: 25,
      );

      cart.agregarAlCarrito(shoe, talla: '41', cantidad: 2);
      expect(cart.totalUnidades, 2);
      expect(cart.totalPrecio, 220.0);

      final order = await cart.procesarCompraSimulada();
      expect(order.id, startsWith('ORD-'));
      expect(order.total, 220.0);
      expect(cart.isEmpty, isTrue);
    });
  });
}
