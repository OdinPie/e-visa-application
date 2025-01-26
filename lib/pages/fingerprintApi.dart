import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:async';

import 'done.dart';


class FingerprintAPI extends StatefulWidget {
  final Map<String, String> fingerprints;

  final String userId;

  const FingerprintAPI({
    super.key,
    required this.fingerprints,
    required this.userId,
  });

  @override
  _FingerprintAPIState createState() => _FingerprintAPIState();
}

class _FingerprintAPIState extends State<FingerprintAPI> {
  final String baseUrl = "http://127.0.0.1:8000";
  List<Map<String, dynamic>> fingerprintRecords = [];
  bool isLoading = false;
  final dateFormatter = DateFormat('MMM dd, yyyy HH:mm');
  // Add this to your _FingerprintAPIState class
  Timer? _refreshTimer;
  int _retryCount = 0;
  static const int maxRetries = 3;

  @override
  void initState() {
    super.initState();
    _uploadFingerprints();
    // Setup auto refresh every 5 days
    _refreshTimer = Timer.periodic(const Duration(days: 5), (timer) {
      fetchFingerprints();
    });
  }
  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }


  Future<void> _uploadFingerprints() async {
    setState(() {
      isLoading = true;
      _retryCount = 0;
    });

    try {
      var request = http.MultipartRequest('POST', Uri.parse("$baseUrl/upload/"));

      request.fields['id'] = widget.userId;
      request.fields['capture_date'] = DateTime.now().toString();

      for (var entry in widget.fingerprints.entries) {
        String fingerName = entry.key.toLowerCase().replaceAll(' ', '_');
        request.fields[fingerName] = entry.value;
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fingerprints uploaded successfully'),
            backgroundColor: Colors.green,
          ),
        );
        await fetchFingerprints();
      } else {
        throw Exception("Failed to upload fingerprints: ${response.statusCode}\n${response.body}");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading fingerprints: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> fetchFingerprints() async {
    if (_retryCount >= maxRetries) {
      setState(() {
        isLoading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to fetch fingerprints after multiple attempts'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.get(Uri.parse("$baseUrl/biometrics/"));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        setState(() {
          fingerprintRecords = data.map((e) => e as Map<String, dynamic>).toList();
          fingerprintRecords.sort((a, b) => b['id'].compareTo(a['id']));
          _retryCount = 0; // Reset retry count on success
        });
      } else {
        throw Exception('Failed to fetch fingerprints');
      }
    } catch (e) {
      print('Error in fetchFingerprints: $e');
      _retryCount++;
      if (_retryCount < maxRetries) {
        // Wait for 2 seconds before retrying
        await Future.delayed(const Duration(seconds: 2));
        await fetchFingerprints();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching fingerprints: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }


  String _formatDateTime(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return dateFormatter.format(dateTime);
    } catch (e) {
      return 'Invalid Date';
    }
  }

  String? _extractPngUrl(dynamic fingerData) {
    if (fingerData is Map<String, dynamic>) {
      return fingerData['png_url'] as String?;
    } else if (fingerData is String) {
      return fingerData;
    }
    return null;
  }



  Widget _buildFingerprintCard(String fingerName, dynamic fingerData) {
    final imageUrl = _extractPngUrl(fingerData);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            if (imageUrl != null)
              Positioned.fill(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                            : null,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    print('Error loading image $imageUrl: $error');
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 32,
                          ),
                          TextButton(
                            onPressed: () {
                              fetchFingerprints(); // Refresh URLs on error
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              )
            else
              const Center(
                child: Icon(
                  Icons.fingerprint,
                  size: 48,
                  color: Colors.grey,
                ),
              ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Text(
                  fingerName.replaceAll('_', ' ').toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> record) {
    final fingerprints = record['fingerprints'] as Map<String, dynamic>;
    final captureDate = record['capture_date'] ?? 'No date';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Record ID: ${record['id']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDateTime(captureDate),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${fingerprints.length} prints',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: fingerprints.length,
            itemBuilder: (context, fingerIndex) {
              final fingerName = fingerprints.keys.elementAt(fingerIndex);
              final fingerData = fingerprints[fingerName];
              return _buildFingerprintCard(fingerName, fingerData);
            },
          ),
          const Divider(height: 32),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        // Add refresh button to the left
        leading: IconButton(
          icon: const Icon(Icons.refresh, color: Colors.black87),
          onPressed: fetchFingerprints,
        ),
        title: const Text(
          "Fingerprint Records",
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [

          // Add next button that navigates to Done page
          IconButton(
            icon: const Icon(Icons.navigate_next, color: Colors.black87),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const done()),
              );
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(
        child: CircularProgressIndicator(),
      )
          : fingerprintRecords.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.fingerprint,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No fingerprint records found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: fetchFingerprints,
              child: const Text('Refresh'),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        onRefresh: fetchFingerprints,
        child: ListView.builder(
          itemCount: fingerprintRecords.length,
          itemBuilder: (context, index) {
            return _buildRecordCard(fingerprintRecords[index]);
          },
        ),
      ),
    );
  }
}