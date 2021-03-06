//
//  DownloadAudio.swift
//  VKMusic
//
//  Created by Yaro on 2/23/18.
//  Copyright © 2018 Yaroslav Dukal. All rights reserved.
//

import Foundation

extension TrackListTableVC: URLSessionDownloadDelegate {
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        
        if let originalURL = downloadTask.originalRequest?.url?.absoluteString,
            let destinationURL = localFilePathForUrl(originalURL) {
            let fileManager = FileManager.default
			// Do this just in case if same file name is already exist. 
			do { try fileManager.removeItem(at: destinationURL) }
			catch let error as Error { //FILE PROBABLY DOES NOT EXIST:
//                print("ERROR REMOVING TEMP FILE: \(error.localizedDescription)")
            }
            self.hideActivityIndicator()
            
            do {
                try fileManager.moveItem(at: location, to: destinationURL)
				if let currentDownload = self.activeDownloads[originalURL] {
					CoreDataManager.shared.saveToCoreData(audio: Audio(url: destinationURL.absoluteString, title: currentDownload.title, artist: currentDownload.artist, duration: currentDownload.duration))
					DispatchQueue.main.async {
						SwiftNotificationBanner.presentNotification("\(currentDownload.songName)\nDownload complete")
						self.activeDownloads[downloadTask.originalRequest?.url?.absoluteString ?? ""] = nil
						self.tableView.reloadData()
					}
				}
            } catch let error as Error {
				DispatchQueue.main.async {
                    print("ERROR: \(error.localizedDescription)")
                    if self.activeDownloads[originalURL] != nil {
                        SwiftNotificationBanner.presentNotification("\(self.activeDownloads[originalURL]!.songName)\n\(error.localizedDescription)")
                        self.activeDownloads[downloadTask.originalRequest?.url?.absoluteString ?? ""] = nil

                        self.tableView.reloadData()
                    }
                }
            }
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        
        if let downloadUrl = downloadTask.originalRequest?.url?.absoluteString,
            let download = activeDownloads[downloadUrl] {
            download.progress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
            let totalSize = ByteCountFormatter.string(fromByteCount: totalBytesExpectedToWrite, countStyle: ByteCountFormatter.CountStyle.binary)
            print(download.progress)
            
            DispatchQueue.main.async {
                
                self.toolBarStatusLabel.text = "Downloading \(String(format: "%.1f%%",  download.progress * 100))"

                
                if let trackIndex = self.trackIndexForDownloadTask(downloadTask),
                    let trackCell = self.tableView.cellForRow(at: IndexPath(row: trackIndex, section: 0)) as? TrackListTableViewCell {
                    trackCell.downloadProgressView.progress = download.progress
                    let bitRate = String(Int(totalBytesExpectedToWrite) * 8 / 1000 / download.duration)
                    trackCell.downloadProgressLabel.text =  String(format: "%.1f%% of %@",  download.progress * 100, totalSize) + " \(bitRate) kbps"
                }
            }
        }
    }
    
    func startDownload(_ track: Audio) {

        if track.url.isEmpty {
            SwiftNotificationBanner.presentNotification("Unable to download. No url")
            return
        }
        
        if track.url.last == "3" { //http://192.168.1.104:8080/downloads/temp.mp3
            showActivityIndicator(withStatus: "Downloading file to local server ...")
            
            GlobalFunctions.shared.getLocalDownloadedFileURL(url: track.url) { (local_url, error) in
                if let new_url = local_url {
                    DispatchQueue.main.async {
                        self.toolBarStatusLabel.text = "Downloading to phone ..."
                    }
                    self.downloadFile(fromURL: new_url, track: track)
                }
            }
        } else {
            downloadFile(fromURL: track.url, track: track)
        }
    }
    
    func downloadFile(fromURL urlString: String, track: Audio) {
        
        let download = Download(url: urlString)
        download.downloadTask = self.downloadsSession.downloadTask(with: URL(string: urlString)!)
        download.downloadTask!.resume()
        download.isDownloading = true
        
        download.fileName = "\(track.title)_\(track.artist)_\(track.duration).mp\(track.url.last ?? "3")"
        download.songName = track.title
        
        //Save info for CoreData:
        download.title = track.title
        download.artist = track.artist
        download.duration = track.duration
        
        activeDownloads[download.url] = download
    }
}
