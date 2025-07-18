// lib/screen/service_finder.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For rootBundle
import 'package:firebase_analytics/firebase_analytics.dart'; // For analytics
import 'package:firebase_storage/firebase_storage.dart'; // For Firebase Storage
import 'package:makkal_sevai_guide/model/department_data.dart';
import 'package:makkal_sevai_guide/model/service_info.dart'; // Import both ServiceInfo and DepartmentData
import 'package:makkal_sevai_guide/widget/service_detail_card.dart'; // Import ServiceDetailCard

// Screen for searching and browsing services
class ServiceFinderScreen extends StatefulWidget {
  final bool isEnglish;
  const ServiceFinderScreen({super.key, required this.isEnglish});

  @override
  State<ServiceFinderScreen> createState() => _ServiceFinderScreenState();
}

class _ServiceFinderScreenState extends State<ServiceFinderScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  final List<ServiceInfo> _allServices = []; // Flat list for search functionality
  List<ServiceInfo> _searchResults = [];
  ServiceInfo? _selectedService;
  final TextEditingController _searchController = TextEditingController();
  bool _showSearchResults = false; // Controls whether to show search results or tabs

  // New: Lists for categorized departments
  List<DepartmentData> _ruralDepartments = [];
  List<DepartmentData> _urbanDepartments = [];

  // TabController for Urban/Rural tabs
  late TabController _tabController;

  // Define Firebase Storage paths for your JSON files
  final String _ruralJsonStoragePath = 'json/rural.json';
  final String _urbanJsonStoragePath = 'json/urban.json';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAllData();
    _searchController.addListener(() {
      setState(() {
        _showSearchResults = _searchController.text.isNotEmpty;
        // If user types, clear selected service to show search results
        _selectedService = null;
      });
      _performSearch(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ServiceFinderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update search bar text if language changes while a service is selected
    if (widget.isEnglish != oldWidget.isEnglish) {
      if (_selectedService != null) {
        _searchController.text = widget.isEnglish ? _selectedService!.serviceNameEn : _selectedService!.serviceName;
      }
    }
  }

  Future<void> _loadAllData() async {
    if (mounted) setState(() => _isLoading = true);
    _allServices.clear();
    _ruralDepartments.clear();
    _urbanDepartments.clear();

    bool loadedFromFirebase = false;

    // --- Attempt to load from Firebase Storage first ---
    try {
      debugPrint("Attempting to load data from Firebase Storage...");
      final FirebaseStorage storage = FirebaseStorage.instance;

      // Fetch Rural data from Firebase
      final Reference ruralRef = storage.ref(_ruralJsonStoragePath);
      final Uint8List? ruralBytes = await ruralRef.getData();
      if (ruralBytes != null) {
        final String ruralResponse = utf8.decode(ruralBytes);
        final List<dynamic> ruralData = json.decode(ruralResponse);
        _ruralDepartments = _parseDepartments(ruralData, 'Rural');
        debugPrint("Successfully loaded Rural data from Firebase.");
        loadedFromFirebase = true;
      } else {
        debugPrint("Rural data not found on Firebase Storage (bytes were null).");
        loadedFromFirebase = false;
      }

      // Fetch Urban data from Firebase - only if rural was successful, or attempt anyway
      if (loadedFromFirebase) { // Only try urban from Firebase if rural succeeded
        final Reference urbanRef = storage.ref(_urbanJsonStoragePath);
        final Uint8List? urbanBytes = await urbanRef.getData();
        if (urbanBytes != null) {
          final String urbanResponse = utf8.decode(urbanBytes);
          final List<dynamic> urbanData = json.decode(urbanResponse);
          _urbanDepartments = _parseDepartments(urbanData, 'Urban');
          debugPrint("Successfully loaded Urban data from Firebase.");
          // loadedFromFirebase remains true
        } else {
          debugPrint("Urban data not found on Firebase Storage (bytes were null). Falling back.");
          loadedFromFirebase = false; // If urban failed, entire Firebase load fails
        }
      } else {
        debugPrint("Skipping Urban Firebase load as Rural Firebase load failed.");
      }

      if (loadedFromFirebase) {
        debugPrint("All data loaded successfully from Firebase Storage.");
      }

    } catch (firebaseError) {
      debugPrint("Failed to load data from Firebase Storage: $firebaseError. Falling back to assets.");
      loadedFromFirebase = false;
      _allServices.clear(); // Clear any partial data loaded from Firebase if an error occurred.
      _ruralDepartments.clear();
      _urbanDepartments.clear();
    }

    // --- Fallback to loading from local assets if Firebase load failed ---
    if (!loadedFromFirebase || (_ruralDepartments.isEmpty && _urbanDepartments.isEmpty)) {
      try {
        debugPrint("Loading data from local assets (fallback)...");
        final String ruralResponse = await rootBundle.loadString('assets/rural.json');
        final List<dynamic> ruralData = json.decode(ruralResponse);
        _ruralDepartments = _parseDepartments(ruralData, 'Rural');
        debugPrint("Successfully loaded Rural data from assets.");

        final String urbanResponse = await rootBundle.loadString('assets/urban.json');
        final List<dynamic> urbanData = json.decode(urbanResponse);
        _urbanDepartments = _parseDepartments(urbanData, 'Urban');
        debugPrint("Successfully loaded Urban data from assets.");

        // Analytics: Log that data was loaded from fallback
        FirebaseAnalytics.instance.logEvent(
          name: 'data_load_source',
          parameters: {
            'source': 'local_assets',
            'status': 'success',
          },
        );

      } catch (assetError) {
        debugPrint("Critical Error: Failed to load data from local assets: $assetError");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(widget.isEnglish ? 'Failed to load data from any source. Please check your internet or restart the app.' : 'எந்த மூலத்திலிருந்தும் தரவை ஏற்ற முடியவில்லை. உங்கள் இணைய இணைப்பைச் சரிபார்க்கவும் அல்லது பயன்பாட்டை மறுதொடக்கம் செய்யவும்.')),
          );
        }
        // Analytics: Log failure from fallback
        FirebaseAnalytics.instance.logEvent(
          name: 'data_load_source',
          parameters: {
            'source': 'local_assets',
            'status': 'failed',
            'error': assetError.toString(),
          },
        );
      }
    } else {
      // Analytics: Log that data was successfully loaded from Firebase
      FirebaseAnalytics.instance.logEvent(
        name: 'data_load_source',
        parameters: {
          'source': 'firebase_storage',
          'status': 'success',
        },
      );
    }

    // Populate _allServices for search functionality from the loaded departments
    _allServices.clear();
    for (var dept in _ruralDepartments) {
      _allServices.addAll(dept.services);
    }
    for (var dept in _urbanDepartments) {
      _allServices.addAll(dept.services);
    }


    if (mounted) {
      setState(() => _isLoading = false);
      if (_searchController.text.isNotEmpty) {
        _performSearch(_searchController.text);
      }
    }
  }

  // New helper method to parse raw JSON into DepartmentData structure
  List<DepartmentData> _parseDepartments(List<dynamic> data, String type) {
    List<DepartmentData> departments = [];
    for (var departmentJson in data) {
      List<ServiceInfo> services = [];
      if (departmentJson['services'] != null) {
        for (var serviceJson in departmentJson['services']) {
          services.add(ServiceInfo.fromJson(departmentJson, serviceJson, type));
        }
      }
      departments.add(DepartmentData(
        departmentName: departmentJson['department'] ?? 'N/A',
        departmentNameEn: departmentJson['department_en'] ?? 'N/A',
        type: type,
        services: services,
      ));
    }
    return departments;
  }

  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    final results = _allServices.where((service) {
      final queryLower = query.toLowerCase();
      return service.serviceName.toLowerCase().contains(queryLower) ||
          service.serviceNameEn.toLowerCase().contains(queryLower);
    }).toList();
    setState(() => _searchResults = results);

    // Analytics for Search Event
    FirebaseAnalytics.instance.logSearch(searchTerm: query);
  }

  void _onSuggestionTapped(ServiceInfo service) {
    _searchController.text = widget.isEnglish ? service.serviceNameEn : service.serviceName;
    FocusScope.of(context).unfocus();
    setState(() {
      _selectedService = service;
      _searchResults = []; // Clear search results to show only the selected service
    });

    // Analytics for Service Detail View Event
    FirebaseAnalytics.instance.logEvent(
      name: 'service_details_viewed', // Custom event name
      parameters: {
        'service_name_en': service.serviceNameEn, // English service name
        'service_name_ta': service.serviceName,   // Tamil service name
        'department_name_en': service.departmentNameEn, // English department name
        'department_name_ta': service.departmentName,   // Tamil department name
        'service_type': service.type,                  // Rural/Urban
        'current_language_viewed': widget.isEnglish ? 'English' : 'Tamil', // Language of the app at time of view
      },
    );
  }

  // New method to clear the selected service and return to list/tabs
  void _clearSelectedService() {
    setState(() {
      _selectedService = null;
      // If search controller is empty, go back to tabs. Otherwise, show search results.
      if (_searchController.text.isEmpty) {
        _showSearchResults = false;
      } else {
        _performSearch(_searchController.text); // Re-run search to show results list
      }
    });
    // Analytics for going back from service details
    FirebaseAnalytics.instance.logEvent(
      name: 'service_details_back_button_clicked',
      parameters: {
        'language': widget.isEnglish ? 'English' : 'Tamil',
      },
    );
  }

  void _clearSearch() {
    _searchController.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      _searchResults = [];
      _selectedService = null;
      _showSearchResults = false; // Hide search results and show tabs when cleared
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ruralColor = isDark ? Colors.green.shade800 : Colors.green.shade100;
    final urbanColor = isDark ? Colors.blue.shade800 : Colors.blue.shade100;

    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0).copyWith(top: 16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: widget.isEnglish ? 'Search for a service' : 'ஒரு சேவையைத் தேடுங்கள்',
              hintText: widget.isEnglish ? 'e.g., Water Connection' : 'எ.கா., குடிநீர் இணைப்பு',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.clear), onPressed: _clearSearch)
                  : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.0)),
            ),
            onChanged: (query) {
              setState(() {
                _showSearchResults = query.isNotEmpty;
                // If user types, clear selected service to show search results
                _selectedService = null;
              });
              _performSearch(query);
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _showSearchResults
              ? // Display Search Results OR Selected Service Detail
          Stack(
            children: [
              if (_selectedService != null) // If a service is selected, show its detail card
                Column( // Wrap ServiceDetailCard in a Column with a back button
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: _clearSelectedService, // Call the new method
                          tooltip: widget.isEnglish ? 'Back to list' : 'பட்டியலுக்குத் திரும்பு',
                        ),
                      ),
                    ),
                    Expanded( // Ensure ServiceDetailCard takes available space
                      child: SingleChildScrollView(
                        child: ServiceDetailCard(
                          service: _selectedService!,
                          isEnglish: widget.isEnglish,
                        ),
                      ),
                    ),
                  ],
                )
              else if (_searchResults.isNotEmpty) // If search results exist, show them
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final service = _searchResults[index];
                      return ListTile(
                        title: Text(widget.isEnglish ? service.serviceNameEn : service.serviceName),
                        subtitle: Text(widget.isEnglish ? service.serviceName : service.serviceNameEn),
                        trailing: Chip(
                          label: Text(service.type),
                          backgroundColor: service.type == 'Rural' ? ruralColor : urbanColor,
                        ),
                        onTap: () => _onSuggestionTapped(service),
                      );
                    },
                  ),
                )
              else // If search is active but no results or selection yet
                Center(
                  child: Text(
                    widget.isEnglish ? 'Type to search for services.' : 'சேவைகளைத் தேட தட்டச்சு செய்யவும்.',
                    style: Theme.of(context).textTheme.bodyLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          )
              : // Display Browsable Departments
          Column(
            children: [
              TabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: widget.isEnglish ? 'Rural Departments' : 'கிராமப்புறத் துறைகள்'),
                  Tab(text: widget.isEnglish ? 'Urban Departments' : 'நகர்ப்புறத் துறைகள்'),
                ],
                onTap: (index) {
                  // Analytics for Tab Switch
                  FirebaseAnalytics.instance.logEvent(
                    name: 'department_tab_switched',
                    parameters: {
                      'tab_name': index == 0 ? 'Rural' : 'Urban',
                      'language': widget.isEnglish ? 'English' : 'Tamil',
                    },
                  );
                },
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDepartmentList(_ruralDepartments, ruralColor, urbanColor),
                    _buildDepartmentList(_urbanDepartments, ruralColor, urbanColor),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // New helper widget for Department List
  Widget _buildDepartmentList(List<DepartmentData> departments, Color ruralColor, Color urbanColor) {
    if (departments.isEmpty) {
      return Center(
        child: Text(
          widget.isEnglish ? 'No departments found.' : 'துறைகள் எதுவும் இல்லை.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }
    return ListView.builder(
      itemCount: departments.length,
      itemBuilder: (context, index) {
        final department = departments[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
          child: ExpansionTile(
            title: Text(
              widget.isEnglish ? department.departmentNameEn : department.departmentName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              widget.isEnglish ? department.departmentName : department.departmentNameEn,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            onExpansionChanged: (isExpanded) {
              // Analytics for Department Expansion
              FirebaseAnalytics.instance.logEvent(
                name: 'department_expanded_toggled',
                parameters: {
                  'department_name_en': department.departmentNameEn,
                  'is_expanded': isExpanded,
                  'language': widget.isEnglish ? 'English' : 'Tamil',
                },
              );
            },
            children: department.services.map((service) {
              return ListTile(
                title: Text(widget.isEnglish ? service.serviceNameEn : service.serviceName),
                subtitle: Text(widget.isEnglish ? service.serviceName : service.serviceNameEn),
                trailing: Chip(
                  label: Text(service.type),
                  backgroundColor: service.type == 'Rural' ? ruralColor : urbanColor,
                ),
                onTap: () {
                  // Analytics for Service Click from Browsable List
                  FirebaseAnalytics.instance.logEvent(
                    name: 'service_clicked_from_browse',
                    parameters: {
                      'service_name_en': service.serviceNameEn,
                      'department_name_en': department.departmentNameEn,
                      'language': widget.isEnglish ? 'English' : 'Tamil',
                    },
                  );
                  _onSuggestionTapped(service); // Reuse existing method to display details
                  // The _onSuggestionTapped method now sets _selectedService and _showSearchResults = true
                  // No need to clear search controller here, as _onSuggestionTapped sets the text for selected service.
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }
}