import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/recipe.dart';

class RecipeService {
  Future<List<Recipe>> loadAll() async {
    final raw = await rootBundle.loadString('assets/recipes.json');
    final rows = jsonDecode(raw) as List<dynamic>;
    return rows.map((e) {
      final j = e as Map<String, dynamic>;
      final items = (j['ingredients'] as List<dynamic>).map((v) {
        final a = v as List<dynamic>;
        return Ingredient((a[1] as String), (a[0] as num).toDouble(), a[2] as String);
      }).toList();
      return Recipe(
        id: j['id'] as String,
        name: j['name'] as String,
        category: j['category'] as String,
        summary: j['summary'] as String,
        ingredients: items,
        jar: JarType.values.firstWhere((x) => x.name == j['jar']),
        knobPosition: j['knob'] as String,
        liquidMl: (j['liquid'] as num).toInt(),
        grindSeconds: (j['seconds'] as num).toInt(),
        intervals: (j['intervals'] as num).toInt(),
        restSeconds: (j['rest'] as num).toInt(),
        texture: GrindTexture.values.firstWhere((x) => x.name == j['texture']),
        precautions: (j['precautions'] as List<dynamic>).cast<String>(),
        icon: j['icon'] as String,
        imageAsset: j['image'] as String?,
      );
    }).toList();
  }

  RecipeRecommendation recommend(Recipe recipe, JarType jar, double ingredientMassG, int liquidMl) {
    final capacity = jar.capacityMl;
    final estimatedTotalMl = ingredientMassG + liquidMl;
    final fillLimit = capacity * 0.68; // conservative UI estimate, not an appliance fill mark
    final batches = (estimatedTotalMl / fillLimit).ceil().clamp(1, 99);
    final totalLiquid = liquidMl;
    final notes = <String>[
      'Starting suggestion only—ingredient shape, moisture, jar assembly and appliance behavior change results.',
      'Knob positions are labels, not electronic speed control. Use only the mixer\'s original controls and manual.',
      'Never exceed the working fill line in the appliance manual; the app estimate is not a certified fill limit.',
    ];
    if (batches > 1) notes.insert(0, 'Split into about $batches smaller batches for this selected jar; re-check the manual fill line.');
    if (totalLiquid == 0 && recipe.texture != GrindTexture.coarse) notes.add('Dry-grinding suitability depends on your jar and manual; no liquid is suggested for this recipe.');
    return RecipeRecommendation(
      batchCount: batches,
      totalSeconds: recipe.grindSeconds * recipe.intervals,
      intervals: recipe.intervals,
      liquidMl: totalLiquid,
      notes: notes,
    );
  }
}
