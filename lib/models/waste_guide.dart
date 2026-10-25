import 'package:flutter/material.dart';

import 'waste_bin.dart';

/// One displayable entry in the Waste Guide.
class WasteGuideItem {
  final String id;
  final String name;
  final String tagalogName;
  final String tip;
  final String category;

  const WasteGuideItem({
    required this.id,
    required this.name,
    required this.tagalogName,
    required this.tip,
    required this.category,
  });

  WasteBin get bin => WasteBin.forCategory(category);
}

/// A Waste Guide category section with rich guidance.
class WasteGuideCategory {
  final String name;
  final String tagalog;
  final String emoji;
  final Color color;
  final Color container;
  final String binHint;
  final String description;
  final String properDisposal;
  final String dontDo;
  final List<WasteGuideItem> items;

  const WasteGuideCategory({
    required this.name,
    required this.tagalog,
    required this.emoji,
    required this.color,
    required this.container,
    required this.binHint,
    required this.description,
    required this.properDisposal,
    required this.dontDo,
    required this.items,
  });

  WasteBin get bin => WasteBin.forCategory(name);
}

/// Static content for the Waste Guide screen.
abstract final class WasteGuideData {
  static const List<WasteGuideCategory> categories = [
    WasteGuideCategory(
      name: 'Biodegradable Waste',
      tagalog: 'Biodegradable',
      emoji: '🌱',
      color: Color(0xFF16A34A),
      container: Color(0xFFDCFCE7),
      binHint: 'Green Bin / Organic Waste Bin',
      description:
          'Biodegradable waste consists of organic materials that naturally decompose through the action of microorganisms such as bacteria and fungi. These wastes come primarily from food, plants, and other natural sources. When properly managed, biodegradable waste can be composted and converted into nutrient-rich organic fertilizer, reducing landfill waste and supporting sustainable agriculture. Separating biodegradable waste from other types of waste also helps reduce unpleasant odors, prevents pest infestations, and lowers greenhouse gas emissions from landfills.',
      properDisposal:
          'Place biodegradable waste in a designated biodegradable or green waste bin. Whenever possible, compost food scraps, fruit and vegetable peelings, leaves, and garden waste to create natural fertilizer. Keep biodegradable waste separate from plastics, glass, metals, and hazardous materials to ensure efficient composting and proper waste management.',
      dontDo:
          'Do not mix biodegradable waste with recyclable materials, electronic waste, hazardous chemicals, or residual waste. Avoid placing plastic bags, glass bottles, aluminum cans, batteries, or chemical containers in the biodegradable bin, as these materials prevent proper decomposition and contaminate compost.',
      items: [
        WasteGuideItem(
          id: 'food_scraps',
          name: 'Food Scraps & Fruit Peelings',
          tagalogName: 'Leftover Food / Fruit Skins',
          tip: 'Place in the green biodegradable bin or compost pit to create natural organic fertilizer.',
          category: 'Biodegradable Waste',
        ),
        WasteGuideItem(
          id: 'leaves',
          name: 'Garden Waste & Leaves',
          tagalogName: 'Leaves & Plant Trimmings',
          tip: 'Compostable material. Collect and place in organic green waste containers.',
          category: 'Biodegradable Waste',
        ),
      ],
    ),
    WasteGuideCategory(
      name: 'Electronic Waste (E-Waste)',
      tagalog: 'E-Waste',
      emoji: '💻',
      color: Color(0xFF7C3AED),
      container: Color(0xFFF3E8FF),
      binHint: 'Authorized E-Waste Center / Drop-off Bin',
      description:
          'Electronic waste, commonly known as e-waste, includes discarded electrical and electronic devices that have reached the end of their useful life or are no longer needed. Many electronic products contain valuable materials such as copper, aluminum, silver, and gold that can be recovered through recycling. However, they may also contain hazardous substances like lead, mercury, and cadmium that can harm human health and the environment if disposed of improperly. Proper e-waste recycling helps conserve natural resources and prevents toxic pollution.',
      properDisposal:
          'Bring unwanted or damaged electronic devices to an authorized electronic waste collection center or certified recycling facility. If the device is still functional, consider donating, repairing, or reusing it. Before disposal, remove any personal information by resetting or wiping storage devices whenever possible.',
      dontDo:
          'Do not throw electronic devices into regular household trash, burn them, dismantle them without proper equipment, or dispose of them together with biodegradable or recyclable waste. Improper disposal can release toxic substances into the soil, water, and air.',
      items: [
        WasteGuideItem(
          id: 'gadgets',
          name: 'Mobile Phones & Laptops',
          tagalogName: 'Old Electronics & Devices',
          tip: 'Wipe personal data first and drop off at certified e-waste collection centers or MRF facilities.',
          category: 'Electronic Waste (E-Waste)',
        ),
        WasteGuideItem(
          id: 'cables_appliances',
          name: 'Cables & Small Appliances',
          tagalogName: 'Wires & Home Gadgets',
          tip: 'Do not throw in regular trash. Take to designated community e-waste collection points.',
          category: 'Electronic Waste (E-Waste)',
        ),
      ],
    ),
    WasteGuideCategory(
      name: 'Hazardous Waste',
      tagalog: 'Hazardous',
      emoji: '☣️',
      color: Color(0xFFDC2626),
      container: Color(0xFFFEF2F2),
      binHint: 'Red Bin / Hazardous Drop-Off Point',
      description:
          'Hazardous waste contains substances that are toxic, flammable, corrosive, reactive, or otherwise dangerous to human health and the environment. Examples include household chemicals, batteries, pesticides, paint, fluorescent lamps, expired medicines, and certain cleaning products. Improper disposal of hazardous waste can contaminate water sources, damage ecosystems, and pose serious health risks to people and animals.',
      properDisposal:
          'Keep hazardous waste in its original container whenever possible and ensure it is tightly sealed. Store it safely away from children, pets, food, and heat sources until it can be delivered to an authorized hazardous waste collection or treatment facility. Follow your local government\'s waste management guidelines for safe disposal.',
      dontDo:
          'Do not pour hazardous chemicals into sinks, toilets, rivers, canals, or drains. Never burn hazardous materials or mix them with household garbage, recyclable materials, or biodegradable waste, as this may cause pollution, fires, or harmful chemical reactions.',
      items: [
        WasteGuideItem(
          id: 'batteries',
          name: 'Batteries & Chemicals',
          tagalogName: 'Batteries & Cleaning Fluids',
          tip: 'Store securely in original containers and bring to local hazardous waste drop-off sites.',
          category: 'Hazardous Waste',
        ),
        WasteGuideItem(
          id: 'paint_lamps',
          name: 'Fluorescent Bulbs & Paints',
          tagalogName: 'Bulbs & Paint Cans',
          tip: 'Handle with care to prevent breakage. Deliver to hazardous treatment centers.',
          category: 'Hazardous Waste',
        ),
      ],
    ),
    WasteGuideCategory(
      name: 'Recyclable Waste',
      tagalog: 'Recyclable',
      emoji: '♻️',
      color: Color(0xFF2563EB),
      container: Color(0xFFDBEAFE),
      binHint: 'Blue Recycling Bin / MRF Center',
      description:
          'Recyclable waste includes materials that can be collected, processed, and transformed into new products instead of being discarded. Common recyclable materials include paper, cardboard, plastic bottles, glass containers, and metal cans. Recycling helps conserve natural resources, reduce energy consumption, minimize pollution, and decrease the amount of waste sent to landfills. Proper segregation plays a vital role in ensuring recyclable materials remain clean and suitable for processing.',
      properDisposal:
          'Clean recyclable containers by removing food residue and liquids before disposal. Dry recyclable items and place them in the designated recycling bin or bring them to a Materials Recovery Facility (MRF) or local recycling center. Flatten cardboard boxes when possible to save storage space.',
      dontDo:
          'Do not place food-contaminated paper, greasy cardboard, broken ceramics, mirrors, tissue paper, or hazardous materials in the recycling bin. Dirty recyclables may contaminate other recyclable materials and reduce recycling efficiency.',
      items: [
        WasteGuideItem(
          id: 'pet_bottle',
          name: 'PET Bottles & Plastics',
          tagalogName: 'Plastic Bottles',
          tip: 'Rinse out contents, remove caps/labels, flatten, and place into the blue recycling bin.',
          category: 'Recyclable Waste',
        ),
        WasteGuideItem(
          id: 'cans_paper',
          name: 'Aluminum Cans & Cardboard',
          tagalogName: 'Cans & Paper Boxes',
          tip: 'Clean and dry thoroughly. Flatten cardboard boxes to maximize storage space.',
          category: 'Recyclable Waste',
        ),
      ],
    ),
    WasteGuideCategory(
      name: 'Residual (Non-Recyclable) Waste',
      tagalog: 'Residual',
      emoji: '🗑️',
      color: Color(0xFF6B7280),
      container: Color(0xFFF3F4F6),
      binHint: 'Black / Gray Waste Container',
      description:
          'Residual waste consists of materials that cannot be recycled, composted, or reused using current waste management methods. These wastes are generally sent to sanitary landfills for final disposal. Common examples include used tissues, disposable diapers, sanitary napkins, candy wrappers, laminated packaging, dirty plastic wrappers, cigarette butts, and heavily contaminated materials. Reducing residual waste is important because it occupies landfill space and may remain in the environment for many years.',
      properDisposal:
          'Place residual waste in the designated residual waste bin or black waste container. Seal waste securely when necessary to prevent odors, leaks, and pest infestation. Dispose of it according to your local government\'s garbage collection schedule.',
      dontDo:
          'Do not mix recyclable materials, biodegradable waste, hazardous waste, or electronic waste with residual waste. Avoid burning residual waste, as it may release harmful smoke and pollutants into the environment.',
      items: [
        WasteGuideItem(
          id: 'diapers_tissues',
          name: 'Used Diapers & Tissues',
          tagalogName: 'Sanitary Waste & Tissues',
          tip: 'Wrap securely, seal tightly, and place in the black/gray residual container.',
          category: 'Residual (Non-Recyclable) Waste',
        ),
        WasteGuideItem(
          id: 'sachet_wrappers',
          name: 'Candy Wrappers & Laminated Sachets',
          tagalogName: 'Foil Packaging & Wrappers',
          tip: 'Dispose in the residual trash container as these packaging items cannot be composted or recycled.',
          category: 'Residual (Non-Recyclable) Waste',
        ),
      ],
    ),
  ];

  /// Every guide item across all categories (single source of truth).
  static List<WasteGuideItem> get items =>
      [for (final category in categories) ...category.items];

  /// The 7-step quick guide for proper waste sorting.
  static const List<({IconData icon, String title, String detail})> steps = [
    (
      icon: Icons.tips_and_updates_rounded,
      title: 'Identify Waste Type',
      detail: 'Determine whether waste is Organic, Recyclable, Residual, E-Waste, or Hazardous.',
    ),
    (
      icon: Icons.handshake_outlined,
      title: 'Separate at Source',
      detail: 'Keep different waste categories isolated in separate bags or bins.',
    ),
    (
      icon: Icons.water_drop_outlined,
      title: 'Rinse & Dry Recyclables',
      detail: 'Clean food residue from plastic bottles, glass, and aluminum cans.',
    ),
    (
      icon: Icons.compress_rounded,
      title: 'Flatten & Compress',
      detail: 'Crush plastic bottles and flatten cardboard boxes to conserve space.',
    ),
    (
      icon: Icons.inventory_2_outlined,
      title: 'Securely Seal Containers',
      detail: 'Tie bags securely to prevent odor, spillages, and pest infestation.',
    ),
    (
      icon: Icons.delete_sweep_rounded,
      title: 'Use Correct Bins',
      detail: 'Deposit waste into designated color-coded bins or collection stations.',
    ),
    (
      icon: Icons.local_shipping_outlined,
      title: 'Special Drop-offs',
      detail: 'Deliver electronic gadgets, batteries, and chemicals to authorized drop-off points.',
    ),
  ];

  /// Find a category matching a category string (fuzzy matching).
  static WasteGuideCategory? findCategory(String name) {
    final search = name.toLowerCase().trim();
    
    // Direct exact match first
    for (final category in categories) {
      final catName = category.name.toLowerCase();
      if (catName == search) return category;
    }
    
    // Priority-based matching for AI responses
    // 1. Electronic Waste (violet) - matched as a whole term so that
    //    "Biodegradable Waste" (ends in "...ble Waste") is not misread as e-waste.
    final eWasteMatcher = RegExp(r'\be[\s-]?waste\b');
    if (search.contains('electronic') || eWasteMatcher.hasMatch(search)) {
      return categories.firstWhere((c) => c.name.toLowerCase().contains('electronic') || c.name.toLowerCase().contains('e-waste'));
    }
    
    // 2. Biodegradable (green) - "non-" prefixes belong to Residual.
    if (!search.contains('non-bio') &&
        !search.contains('non bio') &&
        !search.contains('nonbio') &&
        (search.contains('bio') || search.contains('organic') || search.contains('biodegradable'))) {
      return categories.firstWhere((c) => c.name.toLowerCase().contains('bio'));
    }
    
    // 3. Hazardous (red)
    if (search.contains('hazard') || search.contains('danger') || search.contains('toxic') || search.contains('chemical')) {
      return categories.firstWhere((c) => c.name.toLowerCase().contains('hazard'));
    }
    
    // 4. Recyclable (blue) - "non-" prefixes belong to Residual.
    if (!search.contains('non-recycl') &&
        !search.contains('non recycl') &&
        !search.contains('nonrecycl') &&
        (search.contains('recycl') || search.contains('recycle'))) {
      return categories.firstWhere((c) => c.name.toLowerCase().contains('recycl'));
    }
    
    // 5. Residual (gray)
    if (search.contains('resid') ||
        search.contains('non-recycl') ||
        search.contains('non recycl') ||
        search.contains('nonrecycl') ||
        search.contains('non-bio') ||
        search.contains('non bio') ||
        search.contains('nonbio') ||
        search.contains('general')) {
      return categories.firstWhere((c) => c.name.toLowerCase().contains('resid'));
    }
    
    // Fallback: try partial match - check if category name contains search term
    // or if search term contains any significant part of category name
    for (final category in categories) {
      final catName = category.name.toLowerCase();
      // Extract main category name (before parentheses) for matching
      final mainCatName = catName.split('(')[0].trim();
      final mainSearch = search.split('(')[0].trim();
      
      // Check if main names match partially
      if (mainCatName.contains(mainSearch) || mainSearch.contains(mainCatName)) {
        return category;
      }
      
      // Check if full names contain each other
      if (catName.contains(search) || search.contains(catName)) {
        return category;
      }
    }
    
    // Additional fallback: handle common AI return values
    // Map simple category names to full category names
    final categoryMapping = {
      'biodegradable': 'Biodegradable Waste',
      'organic': 'Biodegradable Waste',
      'compostable': 'Biodegradable Waste',
      'electronic': 'Electronic Waste (E-Waste)',
      'e-waste': 'Electronic Waste (E-Waste)',
      'ewaste': 'Electronic Waste (E-Waste)',
      'e waste': 'Electronic Waste (E-Waste)',
      'hazardous': 'Hazardous Waste',
      'dangerous': 'Hazardous Waste',
      'toxic': 'Hazardous Waste',
      'recyclable': 'Recyclable Waste',
      'recycle': 'Recyclable Waste',
      'residual': 'Residual (Non-Recyclable) Waste',
      'non-recyclable': 'Residual (Non-Recyclable) Waste',
      'non recyclable': 'Residual (Non-Recyclable) Waste',
      'general': 'Residual (Non-Recyclable) Waste',
      'trash': 'Residual (Non-Recyclable) Waste',
    };
    
    for (final key in categoryMapping.keys) {
      if (search.contains(key)) {
        final mappedName = categoryMapping[key];
        return categories.firstWhere((c) => c.name == mappedName);
      }
    }
    
    return null;
  }
}

