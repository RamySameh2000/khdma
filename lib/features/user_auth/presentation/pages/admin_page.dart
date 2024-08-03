import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'models/activity.dart';

class AdminPage extends StatefulWidget {
  @override
  _AdminPageState createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  List<Activity> _pendingRequests = [];

  @override
  void initState() {
    super.initState();
    _fetchPendingRequests();
  }

  Future<void> _fetchPendingRequests() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('requests')
          .where('isApproved', isEqualTo: false)
          .orderBy('timestamp', descending: true)
          .get();

      final List<Activity> requests = snapshot.docs.map((doc) {
        final data = doc.data();
        try {
          // Include document ID in the activity object
          return Activity.fromJson({...data, 'id': doc.id});
        } catch (e) {
          print('Error parsing document data for ${doc.id}: $e');
          return null;
        }
      }).whereType<Activity>().toList();

      setState(() {
        _pendingRequests = requests;
      });
    } catch (e) {
      print('Failed to fetch pending requests: $e');
    }
  }

  Future<void> _updateUserPoints(Activity activity) async {
    try {
      final userDoc = FirebaseFirestore.instance.collection('users').doc(activity.userEmail);
      final doc = await userDoc.get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final currentPoints = data['points'] as int? ?? 0;

        await userDoc.set({
          'points': currentPoints + activity.points,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('Failed to update points: $e');
    }
  }

  Future<void> _confirmActivity(Activity activity) async {
    try {
      await FirebaseFirestore.instance.collection('requests').doc(activity.id).update({
        'isApproved': true,
      });

      await _updateUserPoints(activity);

      setState(() {
        _pendingRequests.remove(activity);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Points successfully added for activity: ${activity.name}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to approve activity: $e')),
      );
    }
  }

  Future<void> _denyActivity(Activity activity) async {
    try {
      await FirebaseFirestore.instance.collection('requests').doc(activity.id).delete();

      setState(() {
        _pendingRequests.remove(activity);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Activity denied: ${activity.name}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to deny activity: $e')),
      );
    }
  }

  Future<void> _approveAll() async {
    for (var activity in List.from(_pendingRequests)) {
      await _confirmActivity(activity);
    }
  }

  Future<void> _denyAll() async {
    for (var activity in List.from(_pendingRequests)) {
      await _denyActivity(activity);
    }
  }

  Widget _buildListTile(Activity activity) {
    final formattedDate = DateFormat('dd/MM/yyyy – hh:mm a').format(activity.timestamp);

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      margin: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
      child: ListTile(
        contentPadding: EdgeInsets.all(15),
        title: Text(
          '${activity.name} (${activity.points} points)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        subtitle: Text(
          'Submitted by: ${activity.userName}\nSubmitted at: $formattedDate',
          style: TextStyle(color: Colors.grey[600], fontSize: 14),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.check, color: Colors.greenAccent),
              onPressed: () => _confirmActivity(activity),
            ),
            IconButton(
              icon: Icon(Icons.close, color: Colors.redAccent),
              onPressed: () => _denyActivity(activity),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Page', style: TextStyle(fontFamily: 'RobotoMono')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _approveAll,
                  icon: Icon(Icons.check, color: Colors.greenAccent),
                  label: Text('Approve All'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.greenAccent, backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _denyAll,
                  icon: Icon(Icons.close, color: Colors.redAccent),
                  label: Text('Deny All'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.redAccent, backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _pendingRequests.length,
              itemBuilder: (context, index) {
                final activity = _pendingRequests[index];
                return _buildListTile(activity);
              },
            ),
          ),
        ],
      ),
    );
  }
}
