import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/api_service.dart';

class ProductTileCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const ProductTileCard({
    super.key,
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: product.imageUrl != null && product.imageUrl!.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    product.imageUrl!.startsWith('http')
                        ? product.imageUrl!
                        : '${ApiService.baseUrl}${product.imageUrl}',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.broken_image, color: Colors.red);
                    },
                  ),
                )
              : const Icon(Icons.inventory_2, color: Colors.blue),
        ),
        title: Text(
          product.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('SKU: ${product.sku}'),
        trailing: Text(
          '${product.price} MMK',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.green,
            fontSize: 16,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
