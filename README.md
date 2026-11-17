# MzaziCare – Elderly Home Caregiver Booking and Recommendation System

**An Explainable Knowledge Graph-Enhanced Hybrid Recommender for Elderly Home Caregiver Matching**

MzaziCare is a mobile-based elderly home care management and caregiver matching system designed to help families find suitable caregivers for their elderly loved ones. The system combines a Neo4j knowledge graph, a Random Forest machine learning model, and SHAP explainability to generate personalised caregiver recommendations that are both relevant and understandable.

The platform also supports care service requests, caregiver availability management, booking coordination, communication, and care updates, creating a centralised environment for managing elderly home care.

---

## Table of Contents

- [Project Overview](#project-overview)
- [Problem Statement](#problem-statement)
- [Project Objectives](#project-objectives)
- [Key Features](#key-features)
- [User Roles](#user-roles)
- [Recommendation System](#recommendation-system)
- [System Architecture](#system-architecture)
- [Technology Stack](#technology-stack)
- [Project Structure](#project-structure)
- [System Requirements](#system-requirements)
- [Installation and Setup](#installation-and-setup)
- [Running the Application](#running-the-application)
- [Recommendation Model](#recommendation-model)
- [Testing](#testing)
- [Security and Privacy](#security-and-privacy)
- [Future Improvements](#future-improvements)
- [Author](#author)

---

## Project Overview

Finding a reliable and suitable caregiver for an elderly person can be challenging. Families need to consider several factors, including the caregiver's skills, experience, services offered, location, availability, and the specific care needs of the elderly person.

MzaziCare addresses this challenge through an intelligent caregiver matching and booking platform.

Families can create profiles, describe their care requirements, receive ranked caregiver recommendations, review explanations behind the recommendations, and manage bookings. Caregivers can maintain their professional profiles, specify their services and skills, manage their schedules, and respond to booking requests.

The system uses a hybrid recommendation approach that combines knowledge graph-based candidate retrieval with machine learning-based suitability prediction. SHAP is incorporated to explain the factors influencing the recommendations.

## Problem Statement

Traditional caregiver selection often relies on manual searching, referrals, and subjective comparisons. This can make it difficult for families to identify caregivers whose qualifications and availability align with the needs of an elderly person.

Additionally, recommendation systems that provide rankings without explaining how those rankings were generated may reduce user trust.

MzaziCare addresses these challenges by providing:

- Structured caregiver and client profiles.
- Intelligent matching based on care requirements.
- Knowledge graph-based candidate retrieval.
- Machine learning-based caregiver suitability scoring.
- Explainable recommendations using SHAP.
- Integrated booking and care coordination features.

## Project Objectives

The main objective is to develop an explainable knowledge graph-enhanced hybrid recommender system for elderly home caregiver matching.

Specific objectives include:

1. Develop a platform for families and caregivers to register and manage their profiles.
2. Capture elderly care requirements, caregiver skills, services, locations, and availability.
3. Implement a Neo4j knowledge graph for representing relationships between clients, caregivers, skills, services, and locations.
4. Develop a hybrid recommendation approach combining knowledge graph candidate retrieval and Random Forest suitability prediction.
5. Integrate SHAP to explain the factors contributing to caregiver recommendations.
6. Implement caregiver booking, scheduling, communication, and care update functionalities.
7. Provide administrative functionality for managing and monitoring the platform.

---

## Key Features

### 1. User Authentication and Profile Management

- Firebase Authentication integration.
- User registration and login.
- Role-based access for families, caregivers, and administrators.
- Family profile management.
- Caregiver profile management.
- Caregiver professional information, including skills, experience, services, and location.

### 2. Intelligent Caregiver Recommendations

Families can submit their care requirements and receive ranked caregiver recommendations.

Recommendations consider factors such as:

- Required care services.
- Caregiver skills.
- Geographic location.
- Availability.
- Years of experience.
- Experience suitability.
- Caregiver ratings.
- Distance.

### 3. Explainable Recommendations

MzaziCare integrates SHAP (SHapley Additive exPlanations) to provide explanations for caregiver suitability predictions.

Rather than displaying only a recommendation score, the system identifies the factors that contributed positively or negatively to the prediction.

These explanations help families understand why a caregiver was recommended and support more informed decision-making.

### 4. Booking and Scheduling

- Families can submit caregiver booking requests.
- Caregivers can accept or decline requests.
- Booking statuses are tracked throughout the care process.
- Caregivers can manage their schedules.
- Families and caregivers can monitor booking progress.

The booking workflow supports the following statuses:

`Pending → Confirmed → In Progress → Completed`

Requests can also be declined or cancelled where applicable.

### 5. Communication and Messaging

The platform provides communication functionality to support coordination between families and caregivers.

### 6. Care Updates and Journaling

Care-related updates can be shared to help families stay informed about the care being provided.

### 7. Administrative Management

The system includes an administrative portal for managing and monitoring platform activities, including user and caregiver information.

---

## User Roles

| User Role | Main Responsibilities |
|---|---|
| Family / Client | Create care requests, manage profiles, view recommendations, book caregivers, communicate, and monitor care updates. |
| Caregiver | Manage professional profiles, specify skills and services, manage availability, respond to bookings, and provide care updates. |
| Administrator | Manage platform users and oversee system activities. |

---

## Recommendation System

The main innovation in MzaziCare is its explainable hybrid caregiver recommendation approach.

The system combines three main components:

1. **Neo4j Knowledge Graph:** Retrieves caregivers whose attributes and relationships match the client's care requirements.
2. **Random Forest Classifier:** Predicts caregiver suitability using structured recommendation features.
3. **SHAP Explainability:** Explains the contribution of individual features to the model's predictions.

### Recommendation Process

The recommendation process follows these steps:

**Step 1: Capture Client Requirements**

The family provides information about the elderly person's care needs, required services, skills, and location.

**Step 2: Knowledge Graph Candidate Retrieval**

The system uses Neo4j to identify potential caregivers based on relationships between clients, caregivers, services, skills, and locations.

**Step 3: Feature Engineering**

The retrieved candidates are converted into structured features for machine learning prediction.

The implemented recommendation model uses eight features:

| Feature | Description |
|---|---|
| `service_match` | Measures how well caregiver services match the requested services. |
| `skill_match` | Measures the match between caregiver skills and required skills. |
| `location_match` | Indicates whether the caregiver's location matches the client's location. |
| `availability_match` | Represents whether the caregiver is available for the requested care. |
| `experience_years` | Represents the caregiver's years of experience. |
| `experience_match` | Measures the suitability of the caregiver's experience. |
| `rating` | Represents the caregiver's rating. |
| `distance_km` | Represents the distance between the client and caregiver. |

**Step 4: Random Forest Prediction**

The structured features are passed to a trained Random Forest classifier, which predicts caregiver suitability.

**Step 5: Recommendation Ranking**

The candidates are ranked according to their predicted suitability, allowing families to view the most suitable available recommendations.

**Step 6: SHAP Explanation**

SHAP is used to explain the model's predictions by identifying the contribution of individual features to the suitability prediction.

The explanations are presented alongside the recommendations to improve transparency.

### Recommendation Architecture

```text
Family / Client
      |
      v
Submit Care Requirements
      |
      v
Django REST API
      |
      v
Neo4j Knowledge Graph
      |
      v
Retrieve Candidate Caregivers
      |
      v
Feature Engineering
      |
      v
Random Forest Classifier
      |
      v
Suitability Prediction
      |
      v
Recommendation Ranking
      |
      v
SHAP Explainability
      |
      v
Ranked Recommendations
with Explanations
      |
      v
Flutter Application
```

### Model Training

The Random Forest model was trained using a synthetic recommendation dataset containing **38,800 records**.

The dataset distribution was:

- Suitable matches: 21,074 (54.31%).
- Unsuitable matches: 17,726 (45.69%).

The dataset was divided into training and testing sets using an 80:20 split with stratification.

The Random Forest classifier was configured with:

| Parameter | Value |
|---|---:|
| Number of estimators | 200 |
| Maximum depth | 12 |
| Minimum samples split | 5 |
| Minimum samples leaf | 2 |
| Class weight | Balanced |
| Random state | 42 |

The model was trained to distinguish suitable from unsuitable caregiver matches using the eight recommendation features.

**Note:** The training dataset is synthetic. Model evaluation results should therefore be interpreted in the context of the generated dataset and should not be treated as proof of performance on real-world caregiver matching data.

---

## System Architecture

MzaziCare follows a client-server architecture.

- The Flutter application provides the user interface.
- Django REST Framework handles backend business logic and API requests.
- PostgreSQL stores structured application data.
- Neo4j stores the knowledge graph and caregiver matching relationships.
- Firebase Authentication manages user authentication.
- Firebase services support application notifications.
- Scikit-learn provides machine learning predictions.
- SHAP generates explanations for model predictions.

---

## Technology Stack

| Component | Technology |
|---|---|
| Mobile application | Flutter |
| Programming language (frontend) | Dart |
| Backend framework | Django |
| API development | Django REST Framework |
| Backend language | Python |
| Relational database | PostgreSQL |
| Graph database | Neo4j |
| Authentication | Firebase Authentication |
| Notifications | Firebase services |
| Machine learning | Scikit-learn |
| Recommendation algorithm | Random Forest Classifier |
| Explainable AI | SHAP |
| Data processing | Pandas |
| Data visualisation | fl_chart |
| Development environment | Visual Studio Code |
| Version control | Git and GitHub |

---

## Project Structure

The repository is organised into the following main directories:

```text
Mzazicare-booking-system/
│
├── backend/
│   ├── accounts/
│   ├── admin_portal/
│   ├── bookings/
│   ├── caregivers/
│   ├── care_coordination/
│   ├── clients/
│   ├── config/
│   ├── notifications/
│   ├── recommendations/
│   ├── manage.py
│   └── requirements.txt
│
├── frontend/
│   ├── android/
│   ├── ios/
│   ├── lib/
│   │   ├── auth/
│   │   ├── booking/
│   │   ├── care_updates/
│   │   ├── dashboards/
│   │   ├── messaging/
│   │   ├── onboarding/
│   │   ├── recommendations/
│   │   ├── screens/
│   │   ├── services/
│   │   ├── theme/
│   │   └── widgets/
│   ├── pubspec.yaml
│   └── pubspec.lock
│
├── ml/
│   ├── models/
│   ├── training/
│   └── ...
│
├── .gitignore
└── README.md
```

The structure may evolve as additional modules and features are developed.

---

## System Requirements

Before setting up the project, ensure that the following are installed:

- Python 3.11 or a compatible version supported by the backend dependencies.
- Flutter SDK.
- Dart SDK (included with Flutter).
- PostgreSQL.
- Neo4j.
- Firebase project with Authentication configured.
- Android Studio or another supported Flutter development environment.
- Visual Studio Code or another code editor.
- Git.

---

## Installation and Setup

### 1. Clone the Repository

```bash
git clone https://github.com/YOUR-GITHUB-USERNAME/Mzazicare-booking-system.git
```

Navigate into the project directory:

```bash
cd Mzazicare-booking-system
```

### 2. Backend Setup

Navigate to the backend directory:

```bash
cd backend
```

Create a Python virtual environment:

```bash
python -m venv .venv
```

Activate the virtual environment.

**Windows PowerShell:**

```powershell
.venv\Scripts\Activate.ps1
```

**Linux / macOS:**

```bash
source .venv/bin/activate
```

Install the backend dependencies:

```bash
pip install -r requirements.txt
```

### 3. Environment Configuration

Create a `.env` file in the backend directory and configure the required environment variables.

Example configuration:

```env
DEBUG=True
SECRET_KEY=your_django_secret_key

DB_NAME=your_database_name
DB_USER=your_database_user
DB_PASSWORD=your_database_password
DB_HOST=localhost
DB_PORT=5432

NEO4J_URI=bolt://localhost:7687
NEO4J_USERNAME=neo4j
NEO4J_PASSWORD=your_neo4j_password

FIREBASE_SERVICE_ACCOUNT_PATH=path/to/firebase-service-account.json
```

The variable names must match those expected by your backend settings. Add any additional configuration required by your local environment.

**Important:** Do not commit `.env` files, Firebase service account JSON files, database passwords, secret keys, or other credentials to GitHub.

### 4. Database Setup

Ensure PostgreSQL is running and create the database configured in your environment variables.

Run Django migrations:

```bash
python manage.py migrate
```

Check the backend configuration:

```bash
python manage.py check
```

Create an administrator account if required:

```bash
python manage.py createsuperuser
```

### 5. Neo4j Configuration

Ensure Neo4j is running and that the database credentials match your backend configuration.

The knowledge graph is used to represent relationships involving:

- Caregivers.
- Clients.
- Locations.
- Skills.
- Services.
- Care requirements.

Run the project's graph synchronisation or data import process where applicable before testing graph-based recommendations.

### 6. Firebase Configuration

Create or configure a Firebase project and enable Firebase Authentication.

Configure the Flutter application using FlutterFire CLI:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

This generates the Firebase configuration file required by the Flutter application.

Configure the Firebase Admin service account for the Django backend separately. Keep the service account file private and outside version control.

### 7. Frontend Setup

Open another terminal and navigate to the frontend directory:

```bash
cd frontend
```

Install Flutter dependencies:

```bash
flutter pub get
```

Ensure the Firebase configuration and backend API base URL are correctly configured for your development environment.

---

## Running the Application

### Start the Backend

From the `backend` directory, activate the virtual environment and run:

```bash
python manage.py runserver
```

The local development server will be available at:

```text
http://127.0.0.1:8000/
```

### Start the Flutter Application

From the `frontend` directory, check available devices:

```bash
flutter devices
```

Run the application:

```bash
flutter run
```

For an Android emulator, ensure the backend API base URL is configured to use the emulator-accessible host address rather than `127.0.0.1`.

For a physical device, configure the API base URL to use the development computer's reachable local network IP address.

---

## Recommendation Model

The trained Random Forest model and its associated feature configuration are maintained in the machine learning directory.

Important files include:

```text
ml/
├── models/
│   ├── caregiver_random_forest.pkl
│   └── feature_columns.json
│
└── training/
    ├── recommendation_training.csv
    ├── caregivers.csv
    ├── caregiver_services.csv
    ├── caregiver_skills.csv
    ├── clients.csv
    ├── client_needs.csv
    └── ...
```

The model and feature configuration must be available to the backend for recommendation predictions.

If the model or knowledge graph is unavailable, recommendation requests should be handled through the backend's error-handling mechanisms rather than returning fabricated recommendations.

---

## Testing

Testing is performed across the main application components to verify that the system operates as expected.

The testing scope includes:

- User registration and authentication.
- Role-based access and profile management.
- Caregiver profile creation and updates.
- Knowledge graph data and candidate retrieval.
- Recommendation feature generation.
- Random Forest suitability predictions.
- SHAP explanation generation.
- Recommendation ranking and presentation.
- Booking creation and status transitions.
- Caregiver schedule management.
- Messaging and care updates.
- Backend API validation and error handling.

Backend checks can be run using:

```bash
python manage.py check
```

Flutter code analysis can be performed using:

```bash
flutter analyze
```

---

## Security and Privacy

MzaziCare handles information relating to families, caregivers, and elderly care requirements. Security and privacy are therefore important considerations.

The system incorporates:

- Firebase-based user authentication.
- Role-based access control.
- Backend API validation.
- Protected application configuration.
- Secure handling of Firebase service account credentials.
- Separation of development secrets from source code.

For production deployment, HTTPS, secure secret management, database access restrictions, appropriate backups, and additional security testing should be configured.

---

## Future Improvements

Potential areas for further development include:

- Integration with real-world caregiver and care-service datasets.
- Further evaluation of recommendation performance using real-world data.
- Additional recommendation model optimisation.
- Expanded administrative analytics and reporting.
- Additional language support.
- Enhanced account security, including multi-factor authentication.
- Cloud deployment and production infrastructure.
- Further usability and accessibility improvements.

---

## Author

**Mary Abiong Arop**

BSc Computer Science  
Strathmore University

**Project:** MzaziCare – An Explainable Knowledge Graph-Enhanced Hybrid Recommender for Elderly Home Caregiver Matching.

**GitHub:** [abiongarop](https://github.com/abiongarop)

---

## Academic Project

MzaziCare is developed as a final-year undergraduate computer science project. It demonstrates the application of mobile application development, backend engineering, graph databases, machine learning, and explainable artificial intelligence to the challenge of elderly home caregiver matching.

