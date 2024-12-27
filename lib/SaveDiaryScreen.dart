import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:io';

class SaveDiaryScreen extends StatelessWidget {
  final List<Map<String, dynamic>> savedDiaries;

  const SaveDiaryScreen({Key? key, required this.savedDiaries}) : super(key: key);

  String _formatDate(String isoDate) {
    DateTime date = DateTime.parse(isoDate);
    return '${date.year}年${date.month}月${date.day}日';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('保存的日記', style: TextStyle(fontSize: 20.sp)),
        backgroundColor: Colors.blueAccent,
      ),
      body: savedDiaries.isEmpty
          ? Center(
        child: Text(
          '暫無保存的日記',
          style: TextStyle(color: Colors.white, fontSize: 16.sp),
        ),
      )
          : ListView.builder(
        itemCount: savedDiaries.length,
        itemBuilder: (context, index) {
          final diary = savedDiaries[index];
          return Card(
            color: Colors.white.withOpacity(0.1),
            margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15.r),
            ),
            child: Padding(
              padding: EdgeInsets.all(15.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 日期和時段
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDate(diary['date']),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        diary['period'],
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14.sp,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  // 心情
                  Row(
                    children: [
                      Icon(
                        Icons.sentiment_satisfied,
                        color: Colors.white,
                        size: 20.sp,
                      ),
                      SizedBox(width: 5.w),
                      Text(
                        diary['mood'],
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  // 日記內容
                  Text(
                    diary['diary'],
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  // 顯示圖片（如果有）
                  if (diary['imagePath'] != null)
                    Container(
                      height: 150.h,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10.r),
                        image: DecorationImage(
                          image: FileImage(File(diary['imagePath'])),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
      backgroundColor: Colors.black,
    );
  }
}
