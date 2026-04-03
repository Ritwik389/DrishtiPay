# DrishtiPay  
**Voice-First UPI Payments for the Visually Impaired**

DrishtiPay is an accessibility-first mobile app that enables visually impaired users to perform secure, independent UPI transactions using voice, AI, and haptics.

---

## Problem
- QR-based payments require precise visual alignment  
- No real-time guidance for visually impaired users  
- Users rely on others, leading to privacy and fraud risks  

---

## Solution
A voice-first accessibility layer that combines:
- Voice guidance (STT + TTS)  
- AI-powered QR scanning  
- Haptic feedback for alignment  
- Secure PIN via handwriting and biometrics  

---

## How to Run the App (from GitHub Repo)

### 1. Clone the Repository
git clone https://github.com/Ritwik389/DrishtiPay.git 
cd DrishtiPay  

### 2. Install Dependencies
flutter pub get  

### 3. Connect a Device / Start Emulator
- Connect your Android device via USB  
- OR start an emulator  

Check devices:
flutter devices  

### 4. Run the App
flutter run  

---

## How to Use the App

1. Launch the app  
2. Follow voice instructions  
3. Point camera towards QR code  
4. Adjust using haptic feedback  
5. Listen to payment details  
6. Confirm via voice  
7. Enter PIN (handwriting or biometrics)  
8. Transaction completes  

---

## Tech Stack
- Flutter + Riverpod (Frontend)  
- Google ML Kit (QR + Ink Recognition)  
- TensorFlow Lite (QR guidance)  
- STT + TTS (Voice interaction)  
- Haptics + Biometrics (Device APIs)  

---

## Impact
- Enables independent payments  
- Reduces fraud risk  
- Expands UPI accessibility  

---

## Future Scope
- Multilingual support (Bhashini)  
- Offline voice recognition  
- Hardware-triggered activation  

---

## Team Pikachu
DTU (Batch of 2029)  
Ritwik Jain • Ananya Mittal • Aarna Gupta  

---

DrishtiPay bridges the last-mile accessibility gap in UPI
