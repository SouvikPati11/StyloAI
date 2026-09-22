import 'package:flutter/material.dart';

/// The six Create sections, with the metadata the UI needs. `supportsReference`
/// marks the flows where the user may upload their own reference image
/// (Outfit, Hair, Glasses — the product requirement).
class CreateType {
  final String type; // backend GenerationType
  final String label;
  final String tagline;
  final IconData icon;
  final bool supportsReference;
  final String referencePurpose; // upload purpose for the reference image
  final String exploreTitle;
  final String uploadTitle;

  const CreateType({
    required this.type,
    required this.label,
    required this.tagline,
    required this.icon,
    required this.supportsReference,
    required this.referencePurpose,
    required this.exploreTitle,
    required this.uploadTitle,
  });
}

const kCreateTypes = <CreateType>[
  CreateType(
    type: 'outfit',
    label: 'Outfit',
    tagline: 'Try on new looks',
    icon: Icons.checkroom,
    supportsReference: true,
    referencePurpose: 'outfit_ref',
    exploreTitle: 'Explore styles',
    uploadTitle: 'Upload an outfit',
  ),
  CreateType(
    type: 'hair',
    label: 'Hair',
    tagline: 'Reimagine your hairstyle',
    icon: Icons.content_cut,
    supportsReference: true,
    referencePurpose: 'hair_ref',
    exploreTitle: 'Explore hairstyles',
    uploadTitle: 'Upload a hairstyle',
  ),
  CreateType(
    type: 'glasses',
    label: 'Glasses',
    tagline: 'Find your frames',
    icon: Icons.remove_red_eye_outlined,
    supportsReference: true,
    referencePurpose: 'glasses_ref',
    exploreTitle: 'Explore glasses',
    uploadTitle: 'Upload glasses',
  ),
  CreateType(
    type: 'accessories',
    label: 'Accessories',
    tagline: 'Add the finishing touch',
    icon: Icons.watch_outlined,
    supportsReference: false,
    referencePurpose: 'accessory_ref',
    exploreTitle: 'Explore accessories',
    uploadTitle: 'Upload a reference',
  ),
  CreateType(
    type: 'pose',
    label: 'Pose',
    tagline: 'Discover pose ideas',
    icon: Icons.accessibility_new,
    supportsReference: false,
    referencePurpose: 'pose_ref',
    exploreTitle: 'Explore poses',
    uploadTitle: 'Upload a pose',
  ),
  CreateType(
    type: 'ai_edit',
    label: 'AI Edit',
    tagline: 'Trending photo styles',
    icon: Icons.auto_awesome,
    supportsReference: false,
    referencePurpose: 'pose_ref',
    exploreTitle: 'Explore styles',
    uploadTitle: 'Upload a reference',
  ),
];

CreateType createTypeByKey(String type) => kCreateTypes
    .firstWhere((t) => t.type == type, orElse: () => kCreateTypes.first);
