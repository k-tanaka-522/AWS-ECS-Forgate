package com.example.ecsforgate.api.service;

import com.example.ecsforgate.api.model.Record;
import com.example.ecsforgate.api.model.RecordStatus;
import com.example.ecsforgate.api.model.dto.CreateRecordRequest;
import com.example.ecsforgate.api.model.dto.RecordDto;
import com.example.ecsforgate.api.repository.RecordRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
public class RecordService {

    private final RecordRepository recordRepository;

    @Transactional(readOnly = true)
    public List<RecordDto> getAllRecords() {
        return recordRepository.findAll().stream()
                .map(RecordDto::fromEntity)
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public RecordDto getRecordById(UUID id) {
        return recordRepository.findById(id)
                .map(RecordDto::fromEntity)
                .orElseThrow(() -> new RuntimeException("Record not found with id: " + id));
    }

    @Transactional
    public RecordDto createRecord(CreateRecordRequest request) {
        Record record = Record.builder()
                .title(request.getTitle())
                .content(request.getContent())
                .status(RecordStatus.DRAFT)
                .createdBy("system")
                .createdAt(OffsetDateTime.now())
                .updatedBy("system")
                .updatedAt(OffsetDateTime.now())
                .build();
        
        Record savedRecord = recordRepository.save(record);
        return RecordDto.fromEntity(savedRecord);
    }
}
